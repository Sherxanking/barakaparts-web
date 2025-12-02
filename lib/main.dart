/// Baraka Parts - Buyurtma va ombor boshqaruv tizimi (MVP)
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
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'core/config/env_config.dart';
import 'infrastructure/datasources/supabase_client.dart';
import 'core/services/auth_state_service.dart';

import 'data/models/department_model.dart';
import 'data/models/product_model.dart';
import 'data/models/part_model.dart';
import 'data/models/order_model.dart';
import 'data/services/language_service.dart';
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

  // PERFORMANCE FIX: Start app immediately, initialize in background
  // WHY: Prevents blocking UI thread, app opens faster
  runApp(const MyApp());

  // Initialize critical services in background (non-blocking)
  // WHY: App can show splash screen while initialization happens
  _initializeServicesInBackground();
}

/// Initialize services in background (non-blocking)
/// WHY: App starts immediately, initialization happens asynchronously
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
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Supabase initialization timeout');
          throw TimeoutException('Supabase initialization timeout');
        },
      );
      debugPrint('✅ Supabase initialized successfully (ANON key)');
      
      // Initialize global auth state service
      // WHY: Sets up global listener for auth state changes (critical for OAuth redirects)
      await AuthStateService().initialize();
      debugPrint('✅ Auth state service initialized');
    } catch (e) {
      debugPrint('⚠️ Supabase initialization failed: $e');
      debugPrint('📱 App offline mode da ishlaydi (Hive cache)');
      // Supabase bo'lmasa ham app ishlashi kerak (offline mode)
    }
    
    // 3. Hive ni initialize qilish (local storage uchun)
    // PERFORMANCE: Initialize Hive in parallel with Supabase if possible
    await Hive.initFlutter();

    // 4. Adapterlarni ro'yxatdan o'tkazish
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

    // 5. Barcha boxlarni ochish (ma'lumotlar bazasi fayllari)
    // PERFORMANCE: Open boxes in parallel where possible
    await Future.wait([
      Hive.openBox<Department>('departmentsBox'),
      Hive.openBox<PartModel>('partsBox'),
      Hive.openBox<Product>('productsBox'),
      Hive.openBox<Order>('ordersBox'),
    ]);

    // 6. Default ma'lumotlarni yuklash (agar boxlar bo'sh bo'lsa)
    // PERFORMANCE: This is non-critical, can happen after app starts
    _initializeDefaultData(); // Don't await - let it run in background
  } catch (e) {
    debugPrint('❌ Background initialization error: $e');
    // Don't crash app - continue with offline mode
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

  /// Initial route - Splash page handles auth guard
  /// WHY: Splash page checks session and navigates appropriately, preventing crashes
  Widget _getInitialRoute() {
    return const SplashPage();
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
      home: _getInitialRoute(), // SplashPage handles auth guard
    );
  }
}
