/// HiveBoxService - Barcha Hive boxlarini markazlashtirilgan boshqaruv
/// 
/// Bu service barcha Hive boxlariga kirishni boshqaradi va 
/// boxlar ochilganligini ta'minlaydi. Singleton pattern ishlatilgan.
/// 
/// FIX: Box ochilganligini tekshirish va xatoliklarni tutish qo'shildi
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/department_model.dart';
import '../models/product_model.dart';
import '../models/part_model.dart';
import '../models/order_model.dart';

class HiveBoxService {
  // Singleton instance
  static final HiveBoxService _instance = HiveBoxService._internal();
  factory HiveBoxService() => _instance;
  HiveBoxService._internal();

  // Box references - lazy initialization
  Box<Department>? _departmentsBox;
  Box<Product>? _productsBox;
  Box<PartModel>? _partsBox;
  Box<Order>? _ordersBox;

  /// Box ochilganligini tekshirish
  /// FIX: Box ochilmagan bo'lsa xatolikni oldini olish
  bool _isBoxOpen(String boxName) {
    try {
      return Hive.isBoxOpen(boxName);
    } catch (e) {
      return false;
    }
  }

  /// Departments box ga kirish
  /// FIX: Box ochilganligini tekshirish va xavfsiz kirish
  Box<Department> get departmentsBox {
    if (_departmentsBox != null && _isBoxOpen('departmentsBox')) {
      return _departmentsBox!;
    }
    try {
      if (_isBoxOpen('departmentsBox')) {
        _departmentsBox = Hive.box<Department>('departmentsBox');
        return _departmentsBox!;
      } else {
        throw StateError('departmentsBox is not open. Call Hive.openBox() first.');
      }
    } catch (e) {
      throw StateError('Failed to access departmentsBox: $e');
    }
  }

  /// Products box ga kirish
  /// FIX: Box ochilganligini tekshirish va xavfsiz kirish
  Box<Product> get productsBox {
    if (_productsBox != null && _isBoxOpen('productsBox')) {
      return _productsBox!;
    }
    try {
      if (_isBoxOpen('productsBox')) {
        _productsBox = Hive.box<Product>('productsBox');
        return _productsBox!;
      } else {
        throw StateError('productsBox is not open. Call Hive.openBox() first.');
      }
    } catch (e) {
      throw StateError('Failed to access productsBox: $e');
    }
  }

  /// Parts box ga kirish
  /// FIX: Box ochilganligini tekshirish va xavfsiz kirish
  Box<PartModel> get partsBox {
    if (_partsBox != null && _isBoxOpen('partsBox')) {
      return _partsBox!;
    }
    try {
      if (_isBoxOpen('partsBox')) {
        _partsBox = Hive.box<PartModel>('partsBox');
        return _partsBox!;
      } else {
        throw StateError('partsBox is not open. Call Hive.openBox() first.');
      }
    } catch (e) {
      throw StateError('Failed to access partsBox: $e');
    }
  }

  /// Orders box ga kirish
  /// FIX: Box ochilganligini tekshirish va xavfsiz kirish
  Box<Order> get ordersBox {
    if (_ordersBox != null && _isBoxOpen('ordersBox')) {
      return _ordersBox!;
    }
    try {
      if (_isBoxOpen('ordersBox')) {
        _ordersBox = Hive.box<Order>('ordersBox');
        return _ordersBox!;
      } else {
        throw StateError('ordersBox is not open. Call Hive.openBox() first.');
      }
    } catch (e) {
      throw StateError('Failed to access ordersBox: $e');
    }
  }

  /// Barcha boxlarni yangilash (ValueListenableBuilder uchun)
  /// FIX: Xavfsiz listenable olish - box ochilganligini tekshirish
  ValueListenable<Box<Department>> get departmentsListenable {
    // Box ochilganligini tekshirish va listenable qaytarish
    if (_isBoxOpen('departmentsBox')) {
      return departmentsBox.listenable();
    }
    // Agar box ochilmagan bo'lsa, departmentsBox getter xatolik beradi
    // Bu holatda ham listenable qaytarish kerak (getter ichida xatolik tutiladi)
    return departmentsBox.listenable();
  }

  ValueListenable<Box<Product>> get productsListenable {
    if (_isBoxOpen('productsBox')) {
      return productsBox.listenable();
    }
    return productsBox.listenable();
  }

  ValueListenable<Box<PartModel>> get partsListenable {
    if (_isBoxOpen('partsBox')) {
      return partsBox.listenable();
    }
    return partsBox.listenable();
  }

  ValueListenable<Box<Order>> get ordersListenable {
    if (_isBoxOpen('ordersBox')) {
      return ordersBox.listenable();
    }
    return ordersBox.listenable();
  }
}

