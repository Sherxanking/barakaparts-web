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
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'data/models/department_model.dart';
import 'data/models/product_model.dart';
import 'data/models/part_model.dart';
import 'data/models/order_model.dart';
import 'data/services/language_service.dart';
import 'l10n/app_localizations.dart';
import 'presentation/pages/home_page.dart';

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
  await Hive.openBox<Department>('departmentsBox');
  await Hive.openBox<PartModel>('partsBox');
  await Hive.openBox<Product>('productsBox');
  await Hive.openBox<Order>('ordersBox');

  // Default ma'lumotlarni yuklash (agar boxlar bo'sh bo'lsa)
  // Bu MVP uchun test ma'lumotlari
  await _initializeDefaultData();

  // Dasturni ishga tushirish
  runApp(const MyApp());
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
  bool _isLocaleLoaded = false;

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
        _isLocaleLoaded = true;
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
      home: const HomePage(), // Asosiy sahifa
    );
  }
}
