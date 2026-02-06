// Baraka Parts - Buyurtma va ombor boshqaruv tizimi (MVP)
/// 
/// Bu loyiha Flutter va Hive asosida qurilgan inventory/order management tizimi.
/// 
/// Arxitektura:
/// - data/models/ - Hive modellar
/// - data/services/ - Business logic va data access
/// - presentation/pages/ - UI sahifalar
/// - presentation/widgets/ - Reusable UI komponentlar
/// 
/// Asosiy funksiyalar:
/// - Department, Product, Part, Order CRUD operatsiyalari
/// - Qidiruv, filtrlash, tartiblash
/// - Real-time yangilanishlar
/// - Stock management va order completion
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'core/services/error_handler_service.dart';

import 'data/models/department_model.dart';
import 'data/models/product_model.dart';
import 'data/models/part_model.dart';
import 'data/models/order_model.dart';
import 'data/services/language_service.dart';
import 'core/config/env_config.dart';
import 'infrastructure/datasources/supabase_client.dart';
import 'core/services/auth_state_service.dart';
import 'core/di/service_locator.dart';
import 'l10n/app_localizations.dart';
import 'presentation/pages/splash_page.dart';

/// Dastur kirish nuqtasi
/// 
/// Bu funksiya:
/// 1. Flutter binding ni ishga tushiradi
/// 2. Hive ni initialize qiladi
/// 3. Barcha adapterlarni ro'yxatdan o'tkazadi
/// 4. Barcha boxlarni ochadi
/// 5. Default ma'lumotlarni yuklaydi (agar bo'sh bo'lsa)
/// 6. Dasturni ishga tushiradi
void main() async {
  // Flutter binding ni ishga tushirish (async operatsiyalar uchun zarur)
  WidgetsFlutterBinding.ensureInitialized();
  
  // Hive ni initialize qilish (local storage uchun)
  await Hive.initFlutter();

  // Adapterlarni ro'yxatdan o'tkazish
  // Har bir model uchun unique typeId ishlatiladi:
  // - Department: 0
  // - PartModel: 1
  // - Product: 2
  // - Order: 3
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(DepartmentAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(PartModelAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(ProductAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(OrderAdapter());
  }

  // Barcha boxlarni ochish (ma'lumotlar bazasi fayllari)
  // Boxlar ochilgunga qadar ularga kirish mumkin emas
  // PERFORMANCE: Open boxes in background to prevent UI blocking
  final boxesFuture = Future.wait([
    Hive.openBox<Department>('departmentsBox'),
    Hive.openBox<PartModel>('partsBox'),
    Hive.openBox<Product>('productsBox'),
    Hive.openBox<Order>('ordersBox'),
    // Cache boxes for repositories
    Hive.openBox<Map>('partsCache'),
    Hive.openBox<Map>('productsCache'),
  ]);

  // Initialize services (cache initialization)
  await ServiceLocator.instance.init();

  // Initialize Supabase and services in background
  _initializeServicesInBackground();

  // Default ma'lumotlarni yuklash (agar boxlar bo'sh bo'lsa)
  // Bu MVP uchun test ma'lumotlari
  _initializeDefaultData(); // Don't await - let it run in background

  // Wait for boxes to open but with timeout to prevent hanging
  try {
    await boxesFuture.timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('⚠️ Boxes opening timeout: $e');
    // Continue anyway to prevent app from freezing
  }

  // Global error handling
  _setupErrorHandling();

  // Dasturni ishga tushirish - runZonedGuarded bilan
  runZonedGuarded(
    () {
      runApp(const MyApp());
    },
    (error, stackTrace) {
      // Zone error handler - async xatoliklarini catch qiladi
      ErrorHandlerService.instance.handleZoneError(error, stackTrace);
    },
  );
}

/// Global error handling setup
void _setupErrorHandling() {
  // Flutter framework xatoliklarini catch qilish
  FlutterError.onError = (FlutterErrorDetails details) {
    ErrorHandlerService.instance.handleFlutterError(details);
  };

  // Platform-specific error handling (Android/iOS)
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    ErrorHandlerService.instance.handleZoneError(error, stackTrace);
    return true; // Error handled
  };
}

/// Initialize services in background (non-blocking)
/// WHY: Supabase va boshqa servislar background'da initialize qilinadi
Future<void> _initializeServicesInBackground() async {
  try {
    // 1. Environment variables yuklash (.env fayldan)
    try {
      await EnvConfig.load();
      debugPrint('✅ Environment variables loaded');
    } catch (e) {
      debugPrint('⚠️ .env fayl yuklanmadi: $e');
      debugPrint('📱 App default sozlamalar bilan ishlaydi');
    }

    // 2. Supabase ni initialize qilish (faqat ANON key!)
    // PERFORMANCE: Initialize with timeout to prevent hanging
    try {
      await AppSupabaseClient.initialize().timeout(
        const Duration(seconds: 8), // Reduced from 10 to 8 seconds
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('⚠️ Supabase initialization timeout');
          }
          throw TimeoutException('Supabase initialization timeout');
        },
      );
      debugPrint('✅ Supabase initialized successfully (ANON key)');

      // Initialize global auth state service
      // WHY: Sets up global listener for auth state changes (critical for OAuth redirects)
      await AuthStateService().initialize();
      debugPrint('✅ Auth state service initialized');
      
      // FIX: Birinchi marta ma'lumotlarni yuklash (agar box'lar bo'sh bo'lsa)
      // WHY: App reinstall qilinganda Supabase'dan ma'lumotlarni yuklash kerak
      // FIX: Background'da ishlaydi - appni bloklamaydi
      // IMPORTANT: Timeout qo'shildi - agar uzoq davom etsa, o'tkazib yuboriladi
      Future.microtask(() { // Changed from delayed to microtask for faster execution
        _syncInitialDataFromSupabase().timeout(
          const Duration(seconds: 12), // Reduced from 15 to 12 seconds
          onTimeout: () {
            debugPrint('⚠️ Data sync timeout - app offline mode da ishlaydi');
          },
        ).catchError((e) {
          debugPrint('⚠️ Data sync error: $e - app offline mode da ishlaydi');
        });
      });
      
      // Initialize realtime streams for products and orders
      // WHY: Keep Hive cache synced with Supabase in real-time
      _initializeRealtimeStreams();
    } catch (e) {
      debugPrint('⚠️ Supabase initialization failed: $e');
      debugPrint('📱 App offline mode da ishlaydi (Hive cache)');
      // Supabase bo'lmasa ham app ishlashi kerak (offline mode)
    }
  } catch (e) {
    debugPrint('❌ Background initialization error: $e');
    // Don't crash app - continue with offline mode
  }
}

/// FIX: Birinchi marta Supabase'dan ma'lumotlarni yuklash
/// WHY: App reinstall qilinganda Hive box'lar bo'sh bo'ladi, Supabase'dan yuklash kerak
Future<void> _syncInitialDataFromSupabase() async {
  try {
    // FIX: Supabase initialize bo'lishini tekshirish
    if (!AppSupabaseClient.isInitialized) {
      debugPrint('⚠️ Supabase hali initialize bo\'lmagan, yuklash o\'tkazib yuborildi');
      return;
    }
    
    final partsBox = Hive.box<PartModel>('partsBox');
    final productsBox = Hive.box<Product>('productsBox');
    final ordersBox = Hive.box<Order>('ordersBox');
    final departmentsBox = Hive.box<Department>('departmentsBox');
    
    // Agar barcha box'lar bo'sh bo'lsa, Supabase'dan yuklash
    final isEmpty = partsBox.isEmpty && productsBox.isEmpty && 
                    ordersBox.isEmpty && departmentsBox.isEmpty;
    
    debugPrint('🔍 Box\'lar holati: parts=${partsBox.length}, products=${productsBox.length}, orders=${ordersBox.length}, departments=${departmentsBox.length}');
    
    if (isEmpty) {
      debugPrint('📥 Box\'lar bo\'sh, Supabase\'dan ma\'lumotlarni yuklayapman...');
      
      final partRepository = ServiceLocator.instance.partRepository;
      final productRepository = ServiceLocator.instance.productRepository;
      final orderRepository = ServiceLocator.instance.orderRepository;
      final supabaseClient = AppSupabaseClient.instance.client;
      
      // Parts yuklash va Hive box'ga yozish
      debugPrint('🔄 Parts yuklayapman...');
      final partsResult = await partRepository.getAllParts();
      await partsResult.fold(
        (failure) async {
          debugPrint('❌ Parts yuklanmadi: ${failure.message}');
          debugPrint('   Failure type: ${failure.runtimeType}');
        },
        (parts) async {
          debugPrint('✅ ${parts.length} ta part yuklandi Supabase\'dan');
          if (parts.isEmpty) {
            debugPrint('⚠️ Parts ro\'yxati bo\'sh, Supabase\'da ma\'lumotlar yo\'q');
          } else {
            // FIX: Repository cache'ga yozadi, lekin asosiy box'ga yozish kerak
            for (var part in parts) {
              final partModel = PartModel(
                id: part.id,
                name: part.name,
                quantity: part.quantity,
                minQuantity: part.minQuantity,
                status: part.quantity < part.minQuantity ? 'lowstock' : 'available',
                imagePath: part.imagePath,
              );
              await partsBox.add(partModel);
            }
            debugPrint('✅ ${parts.length} ta part Hive box\'ga yozildi');
          }
        },
      );
      
      // Products yuklash va Hive box'ga yozish
      debugPrint('🔄 Products yuklayapman...');
      final productsResult = await productRepository.getAllProducts();
      await productsResult.fold(
        (failure) async {
          debugPrint('❌ Products yuklanmadi: ${failure.message}');
          debugPrint('   Failure type: ${failure.runtimeType}');
        },
        (products) async {
          debugPrint('✅ ${products.length} ta product yuklandi Supabase\'dan');
          if (products.isEmpty) {
            debugPrint('⚠️ Products ro\'yxati bo\'sh, Supabase\'da ma\'lumotlar yo\'q');
          } else {
            // FIX: Repository cache'ga yozadi, lekin asosiy box'ga yozish kerak
            for (var product in products) {
              final productModel = Product(
                id: product.id,
                name: product.name,
                departmentId: product.departmentId,
                parts: product.partsRequired, // FIX: Domain entity'da partsRequired deb nomlangan
              );
              await productsBox.add(productModel);
            }
            debugPrint('✅ ${products.length} ta product Hive box\'ga yozildi');
          }
        },
      );
      
      // Orders yuklash va Hive box'ga yozish
      debugPrint('🔄 Orders yuklayapman...');
      final ordersResult = await orderRepository.getAllOrders();
      await ordersResult.fold(
        (failure) async {
          debugPrint('❌ Orders yuklanmadi: ${failure.message}');
          debugPrint('   Failure type: ${failure.runtimeType}');
        },
        (orders) async {
          debugPrint('✅ ${orders.length} ta order yuklandi Supabase\'dan');
          if (orders.isEmpty) {
            debugPrint('⚠️ Orders ro\'yxati bo\'sh, Supabase\'da ma\'lumotlar yo\'q');
          } else {
            // FIX: Repository cache'ga yozadi, lekin asosiy box'ga yozish kerak
            for (var order in orders) {
              final orderModel = Order(
                id: order.id,
                departmentId: order.departmentId,
                productName: order.productName,
                quantity: order.quantity,
                status: order.status,
                createdAt: order.createdAt,
              );
              await ordersBox.add(orderModel);
            }
            debugPrint('✅ ${orders.length} ta order Hive box\'ga yozildi');
          }
        },
      );
      
      // Departments yuklash (to'g'ridan-to'g'ri Supabase'dan)
      try {
        final response = await supabaseClient
            .from('departments')
            .select()
            .order('name');
        
        final departments = (response as List).map((json) {
          return Department(
            id: json['id'] as String,
            name: json['name'] as String,
            productIds: [], // Hive'dan keyin to'ldiriladi
            productParts: {},
          );
        }).toList();
        
        if (departments.isNotEmpty) {
          await _updateDepartmentsBox(departments);
          debugPrint('✅ ${departments.length} ta department yuklandi');
        }
      } catch (e) {
        debugPrint('⚠️ Departments yuklanmadi: $e');
      }
      
      // FIX: Agar Supabase'da ma'lumotlar bo'sh bo'lsa, default ma'lumotlarni yuklash
      final finalPartsCount = partsBox.length;
      final finalProductsCount = productsBox.length;
      final finalOrdersCount = ordersBox.length;
      final finalDepartmentsCount = departmentsBox.length;
      
      debugPrint('📊 Yakuniy holat: parts=$finalPartsCount, products=$finalProductsCount, orders=$finalOrdersCount, departments=$finalDepartmentsCount');
      
      // Agar hali ham bo'sh bo'lsa, default ma'lumotlarni yuklash
      if (finalPartsCount == 0 && finalProductsCount == 0 && finalDepartmentsCount == 0) {
        debugPrint('⚠️ Supabase\'da ma\'lumotlar yo\'q, default ma\'lumotlarni yuklayapman...');
        await _initializeDefaultData();
        debugPrint('✅ Default ma\'lumotlar yuklandi');
      } else {
        debugPrint('✅ Barcha ma\'lumotlar Supabase\'dan yuklandi va Hive box\'larga yozildi');
      }
    } else {
      debugPrint('📦 Box\'larda ma\'lumotlar bor, yuklash o\'tkazib yuborildi');
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Initial data sync xatosi: $e');
    debugPrint('Stack trace: $stackTrace');
    // Xato bo'lsa ham app ishlashi kerak
  }
}

/// Initialize realtime streams for products and orders
/// WHY: Keep Hive cache synced with Supabase in real-time across all devices
void _initializeRealtimeStreams() {
  try {
    final productRepository = ServiceLocator.instance.productRepository;
    final partRepository = ServiceLocator.instance.partRepository;
    final orderRepository = ServiceLocator.instance.orderRepository;
    final supabaseClient = AppSupabaseClient.instance.client;
    
    // Products stream - updates Hive cache automatically
    productRepository.watchProducts().listen(
      (result) {
        result.fold(
          (failure) {
            debugPrint('⚠️ Products stream error: ${failure.message}');
          },
          (products) {
            debugPrint('✅ Products realtime update: ${products.length} products');
            // Cache is automatically updated by repository
          },
        );
      },
      onError: (error) {
        debugPrint('❌ Products stream error: $error');
      },
      cancelOnError: false, // Keep listening even on errors
    );
    debugPrint('✅ Products realtime stream initialized');
    
    // Parts stream - updates Hive cache automatically
    partRepository.watchParts().listen(
      (result) {
        result.fold(
          (failure) {
            debugPrint('⚠️ Parts stream error: ${failure.message}');
          },
          (parts) {
            debugPrint('✅ Parts realtime update: ${parts.length} parts');
            // Cache is automatically updated by repository
          },
        );
      },
      onError: (error) {
        debugPrint('❌ Parts stream error: $error');
      },
      cancelOnError: false, // Keep listening even on errors
    );
    debugPrint('✅ Parts realtime stream initialized');
    
    // Orders stream - updates Hive cache automatically
    orderRepository.watchOrders().listen(
      (result) {
        result.fold(
          (failure) {
            debugPrint('⚠️ Orders stream error in main.dart: ${failure.message}');
          },
          (orders) {
            debugPrint('✅ Orders realtime update in main.dart: ${orders.length} orders');
            // Cache and Hive box are automatically updated by repository
          },
        );
      },
      onError: (error, stackTrace) {
        debugPrint('❌ Orders stream error in main.dart: $error');
        debugPrint('Stack trace: $stackTrace');
      },
      cancelOnError: false, // Keep listening even on errors
    );
    debugPrint('✅ Orders realtime stream initialized');
    
    // Departments stream - updates Hive cache automatically
    // FIX: Departments uchun repository yo'q, shuning uchun to'g'ridan-to'g'ri Supabase stream ishlatamiz
    supabaseClient
        .from('departments')
        .stream(primaryKey: ['id'])
        .order('name')
        .listen(
          (data) {
            try {
              final departments = (data as List).map((json) {
                return Department(
                  id: json['id'] as String,
                  name: json['name'] as String,
                  productIds: [], // FIX: Supabase'da saqlanmaydi, Hive'dan olinadi
                  productParts: {}, // FIX: Supabase'da saqlanmaydi, Hive'dan olinadi
                );
              }).toList();
              
              debugPrint('✅ Departments realtime update: ${departments.length} departments');
              
              // Update Hive box
              _updateDepartmentsBox(departments).catchError((e) {
                debugPrint('⚠️ DepartmentsBox update error: $e');
              });
            } catch (e) {
              debugPrint('❌ Error processing departments stream: $e');
            }
          },
          onError: (error) {
            debugPrint('❌ Departments stream error: $error');
          },
          cancelOnError: false,
        );
    debugPrint('✅ Departments realtime stream initialized');
    
  } catch (e) {
    debugPrint('⚠️ Failed to initialize realtime streams: $e');
    // Don't crash app - continue without realtime sync
  }
}

/// Update departmentsBox with departments from Supabase
Future<void> _updateDepartmentsBox(List<Department> departments) async {
  try {
    if (!Hive.isBoxOpen('departmentsBox')) {
      await Hive.openBox<Department>('departmentsBox');
    }
    final box = Hive.box<Department>('departmentsBox');
    
    // FIX: Mavjud department'larni saqlab qolish (productIds ni yo'qotmaslik uchun)
    final existingDepartments = <String, Department>{};
    for (var dept in box.values) {
      existingDepartments[dept.id] = dept;
    }
    
    await box.clear();
    
    for (var department in departments) {
      // FIX: Mavjud department bo'lsa, productIds va productParts ni saqlab qolish
      final existing = existingDepartments[department.id];
      if (existing != null) {
        department.productIds = existing.productIds;
        department.productParts = existing.productParts;
      }
      await box.add(department);
    }
    debugPrint('✅ DepartmentsBox updated with ${departments.length} departments');
  } catch (e) {
    debugPrint('⚠️ Error updating departmentsBox: $e');
  }
}

/// Default ma'lumotlarni yuklash
/// 
/// Bu funksiya boxlar bo'sh bo'lganda test/demo ma'lumotlarini yuklaydi:
/// - 4 ta part (Screw M5, Bolt M8, Washer, Nut M5)
/// - 3 ta department (Assembly, Packaging, Quality Control)
/// - 3 ta product (Widget A, B, C) - parts bilan biriktirilgan
/// 
/// Bu ma'lumotlar faqat birinchi marta yuklanadi.
/// Keyingi ishga tushirishlarda mavjud ma'lumotlar saqlanadi.
Future<void> _initializeDefaultData() async {
  final departmentsBox = Hive.box<Department>('departmentsBox');
  final partsBox = Hive.box<PartModel>('partsBox');
  final productsBox = Hive.box<Product>('productsBox');

  // Only initialize if boxes are empty
  if (departmentsBox.isEmpty || partsBox.isEmpty || productsBox.isEmpty) {
    const uuid = Uuid();

    // Create default parts
    // FIX: minQuantity field qo'shildi (backward compatible - default 3)
    if (partsBox.isEmpty) {
      final part1 = PartModel(
        id: uuid.v4(),
        name: 'Screw M5',
        quantity: 100,
        status: 'available',
        minQuantity: 20, // Minimal miqdor threshold
      );
      final part2 = PartModel(
        id: uuid.v4(),
        name: 'Bolt M8',
        quantity: 50,
        status: 'available',
        minQuantity: 15,
      );
      final part3 = PartModel(
        id: uuid.v4(),
        name: 'Washer',
        quantity: 200,
        status: 'available',
        minQuantity: 50,
      );
      final part4 = PartModel(
        id: uuid.v4(),
        name: 'Nut M5',
        quantity: 150,
        status: 'available',
        minQuantity: 40,
      );

      await partsBox.add(part1);
      await partsBox.add(part2);
      await partsBox.add(part3);
      await partsBox.add(part4);
    }

    // Create default departments
    if (departmentsBox.isEmpty) {
      final dept1 = Department(
        id: uuid.v4(),
        name: 'Assembly',
        productIds: [],
        productParts: {},
      );
      final dept2 = Department(
        id: uuid.v4(),
        name: 'Packaging',
        productIds: [],
        productParts: {},
      );
      final dept3 = Department(
        id: uuid.v4(),
        name: 'Quality Control',
        productIds: [],
        productParts: {},
      );

      await departmentsBox.add(dept1);
      await departmentsBox.add(dept2);
      await departmentsBox.add(dept3);
    }

    // Create default products
    // FIX: departmentsBox bo'sh bo'lishi mumkin - tekshirish qo'shildi
    if (productsBox.isEmpty) {
      final parts = partsBox.values.toList();
      // FIX: departmentsBox bo'sh bo'lmasligini tekshirish
      if (parts.length >= 4 && departmentsBox.isNotEmpty) {
        final dept1 = departmentsBox.values.first;
        
        final product1 = Product(
          id: uuid.v4(),
          name: 'Widget A',
          departmentId: dept1.id,
          parts: {
            parts[0].id: 2, // 2 screws per widget
            parts[1].id: 1, // 1 bolt per widget
          },
        );
        final product2 = Product(
          id: uuid.v4(),
          name: 'Widget B',
          departmentId: dept1.id,
          parts: {
            parts[0].id: 4, // 4 screws per widget
            parts[2].id: 2, // 2 washers per widget
            parts[3].id: 2, // 2 nuts per widget
          },
        );
        final product3 = Product(
          id: uuid.v4(),
          name: 'Widget C',
          departmentId: dept1.id,
          parts: {
            parts[1].id: 2, // 2 bolts per widget
            parts[2].id: 4, // 4 washers per widget
          },
        );

        await productsBox.add(product1);
        await productsBox.add(product2);
        await productsBox.add(product3);

        // Update department productIds
        dept1.productIds.addAll([product1.id, product2.id, product3.id]);
        await dept1.save();
      }
    }
  }
}

/// Asosiy app widget
/// 
/// Bu widget MaterialApp ni yaratadi va barcha sahifalarni boshqaradi.
/// HomePage bottom navigation bar bilan 4 ta asosiy sahifani ko'rsatadi:
/// - Orders: Buyurtmalar
/// - Departments: Bo'limlar
/// - Products: Mahsulotlar
/// - Parts: Qismlar
/// 
/// Multi-language support: Uzbek, Russian, English
/// Language preference is saved and persists across app restarts.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();
}

/// App state class - til o'zgarishini boshqarish uchun
/// FIX: Async initState muammosini hal qilish - FutureBuilder yoki mounted check
class MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    // FIX: Async operatsiyani initState dan tashqarida bajarish
    _loadLocale();
  }

  /// Saqlangan til sozlamasini yuklash yoki qurilma tilidan foydalanish
  /// FIX: mounted check qo'shildi - widget dispose bo'lganda setState chaqirmaslik
  Future<void> _loadLocale() async {
    final locale = await LanguageService.getLocale();
    if (mounted) {
      setState(() {
        _locale = locale;
      });
    }
  }

  /// App tilini o'zgartirish (Settings sahifasidan chaqiriladi)
  void changeLocale(Locale newLocale) {
    setState(() {
      _locale = newLocale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Baraka Parts',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Material Design 3
      ),
      // Localization support
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('uz', ''), // Uzbek
        Locale('ru', ''), // Russian
        Locale('en', ''), // English
      ],
      home: const SplashPage(), // Splash handles auth guard
    );
  }
}
