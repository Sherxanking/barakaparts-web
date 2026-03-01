/// OrderService - Order bilan ishlash uchun business logic
/// 
/// Bu service order CRUD operatsiyalarini, qidiruv, filtrlash, 
/// tartiblash va order completion (stock reduction) funksiyalarini boshqaradi.
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/order_model.dart' as data;
import '../models/taken_item.dart'; // TakenItem model
import '../models/product_model.dart';
import 'hive_box_service.dart';
import 'product_service.dart';
import 'part_service.dart';
import '../../domain/entities/order.dart' as domain;
import '../../domain/entities/user.dart' as user_domain; // To'g'ri import
import '../../core/di/service_locator.dart';
import '../../core/services/auth_state_service.dart'; // AuthStateService import
import '../../core/services/telegram_notification_service.dart'; // Telegram notification service

class OrderService {
  final HiveBoxService _boxService = HiveBoxService();
  final ProductService _productService = ProductService();
  final PartService _partService = PartService();
  
  // Repository for Supabase sync
  final _orderRepository = ServiceLocator.instance.orderRepository;

  // Hive box name for orders
  static const String _orderBoxName = 'orders';

  /// Barcha orderlarni olish
  /// FIX: Xavfsiz box kirish - xatolik bo'lsa bo'sh ro'yxat qaytarish
  List<data.Order> getAllOrders() {
    try {
      return _boxService.ordersBox.values.toList();
    } catch (e) {
      // Box ochilmagan yoki xatolik bo'lsa bo'sh ro'yxat qaytarish
      return [];
    }
  }

  /// ID bo'yicha order topish
  data.Order? getOrderById(String id) {
    // Hive boxda ID key emas, shuning uchun barcha elementlarni qidirish kerak
    try {
      // Hive boxda ID key emas, shuning uchun barcha elementlarni qidirish kerak
      // Agar box key-value bo'lsa, get(id) ishlatiladi. Hozirda values.firstWhere
      // ishlatilgani uchun, bu ID ni qidirishni anglatadi.
      // Agar Hive box key-value sifatida order.id ni saqlasa, _boxService.ordersBox.get(id) ishlatiladi.
      // Hozirgi implementatsiyada ordersBox.add(order) ishlatilgan, bu esa int indexni key sifatida ishlatadi.
      // Shuning uchun, ID bo'yicha topish uchun values.firstWhere ishlatish to'g'ri.
      return _boxService.ordersBox.values.firstWhere(
        (order) => order.id == id,
        orElse: () => throw StateError('Order not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Order qo'shish
  /// FIX: Hive va Supabase'ga yozish (realtime sync uchun)
  Future<bool> addOrder(data.Order order) async {
    try {
      // 1. Supabase'ga yozish (realtime sync uchun)
      // NOTE: Order model'da productId yo'q, faqat productName bor
      // Domain Order'da productId kerak, shuning uchun productName'dan productId topamiz
      String? productId;
      try {
        // ProductName bo'yicha product topish
        final products = _productService.getAllProducts();
        final product = products.firstWhere(
          (p) => p.name == order.productName,
          orElse: () => throw StateError('Product not found'),
        );
        productId = product.id;
      } catch (e) {
        debugPrint('⚠️ Could not find product ID for ${order.productName}: $e');
        // Product topilmasa, productName'ni productId sifatida ishlatamiz
        // (Bu ideal emas, lekin Supabase'ga yozish uchun zarur)
        productId = order.productName; // Temporary fallback
      }
      
      final domainOrder = domain.Order(
        id: order.id,
        productId: productId,
        productName: order.productName,
        quantity: order.quantity,
        departmentId: order.departmentId,
        status: order.status,
        createdAt: order.createdAt,
      );
      
      final result = await _orderRepository.createOrder(domainOrder);
      
      return result.fold(
        (failure) {
          debugPrint('❌ Failed to create order in Supabase: ${failure.message}');
          // Supabase'ga yozish xato bo'lsa ham Hive'ga yozishga harakat qilamiz
          try {
            _boxService.ordersBox.add(order);
            return true; // Hive'ga yozildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (createdOrder) {
          // 2. Hive'ga ham yozish (offline cache uchun)
          try {
            _boxService.ordersBox.add(order);
            debugPrint('✅ Order created in both Supabase and Hive');
            
            // 3. Telegram notification yuborish
            _sendOrderCreationNotification(order);
            
            return true;
          } catch (e) {
            debugPrint('⚠️ Order created in Supabase but failed to save to Hive: $e');
            return true; // Supabase'ga yozildi, bu asosiy
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in addOrder: $e');
      return false;
    }
  }

  /// Telegram notification yuborish (Creation va Shortage uchun)
  void _sendOrderCreationNotification(data.Order order) async {
    try {
      // 1. Umumiy yaratilganligi haqida habar
      TelegramNotificationService.sendOrderCreatedNotification(
        order.productName,
        order.quantity,
      );

      // 2. Shortage tekshirish va habar yuborish
      final shortages = <Map<String, dynamic>>[];
      final product = _productService.getAllProducts().firstWhere(
        (p) => p.name == order.productName,
        orElse: () => throw StateError('Product not found'),
      );

      for (var entry in product.parts.entries) {
        final partId = entry.key;
        final qtyPerProduct = entry.value;
        final totalNeeded = qtyPerProduct * order.quantity;
        
        final part = _partService.getPartById(partId);
        final currentStock = part?.quantity ?? 0;
        
        if (currentStock < totalNeeded) {
          shortages.add({
            'partName': part?.name ?? partId,
            'shortage': totalNeeded - currentStock,
            'currentStock': currentStock,
          });
        }
      }

      if (shortages.isNotEmpty) {
        TelegramNotificationService.sendPartsShortageNotification(shortages);
      }
    } catch (e) {
      debugPrint('⚠️ Error sending telegram notification: $e');
    }
  }

  /// Order yangilash
  /// FIX: Hive va Supabase'ga yozish (realtime sync uchun)
  Future<bool> updateOrder(data.Order order) async {
    try {
      // 1. Supabase'ga yozish (realtime sync uchun)
      // ProductId topish
      String? productId;
      try {
        final products = _productService.getAllProducts();
        final product = products.firstWhere(
          (p) => p.name == order.productName,
          orElse: () => throw StateError('Product not found'),
        );
        productId = product.id;
      } catch (e) {
        productId = order.productName; // Fallback
      }
      
      final domainOrder = domain.Order(
        id: order.id,
        productId: productId,
        productName: order.productName,
        quantity: order.quantity,
        departmentId: order.departmentId,
        status: order.status,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );
      
      final result = await _orderRepository.updateOrder(domainOrder);
      
      return await result.fold(
        (failure) async {
          debugPrint('❌ Failed to update order in Supabase: ${failure.message}');
          // Supabase'ga yozish xato bo'lsa ham Hive'ga yozishga harakat qilamiz
          try {
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.put(order.id, order);
            return true; // Hive'ga yozildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (updatedOrder) async {
          // 2. Hive'ga ham yozish (offline cache uchun)
          try {
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.put(order.id, order);
            debugPrint('✅ Order updated in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Order updated in Supabase but failed to save to Hive: $e');
            return true; // Supabase'ga yozildi, bu asosiy
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in updateOrder: $e');
      return false;
    }
  }

  /// Order o'chirish - ID bo'yicha
  /// FIX: Hive va Supabase'dan o'chirish (realtime sync uchun)
  Future<bool> deleteOrderById(String orderId) async {
    try {
      // 1. Supabase'dan o'chirish (realtime sync uchun)
      final result = await _orderRepository.deleteOrder(orderId);
      
      return await result.fold(
        (failure) async {
          debugPrint('❌ Failed to delete order in Supabase: ${failure.message}');
          // Supabase'dan o'chirish xato bo'lsa ham Hive'dan o'chirishga harakat qilamiz
          try {
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.delete(orderId);
            return true; // Hive'dan o'chirildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (_) async {
          // 2. Hive'dan ham o'chirish (offline cache uchun)
          try {
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.delete(orderId);
            debugPrint('✅ Order deleted from both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Order deleted from Supabase but failed to delete from Hive: $e');
            return true; // Supabase'dan o'chirildi, bu asosiy
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in deleteOrderById: $e');
      return false;
    }
  }

  /// Order o'chirish - index bo'yicha (legacy, faqat backward compatibility uchun)
  @Deprecated('Use deleteOrderById instead')
  Future<void> deleteOrder(int index) async {
    if (index >= 0 && index < _boxService.ordersBox.length) {
      await _boxService.ordersBox.deleteAt(index);
    }
  }

  /// Order statusini yangilash
  /// FIX: Supabase'ga ham yozish (realtime sync uchun)
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final data.Order? order = getOrderById(orderId);
      if (order == null) {
        return false;
      }
      
      // 1. Supabase'ga yozish (realtime sync uchun)
      // ProductId topish
      String? productId;
      try {
        final products = _productService.getAllProducts();
        final product = products.firstWhere(
          (p) => p.name == order.productName,
          orElse: () => throw StateError('Product not found'),
        );
        productId = product.id;
      } catch (e) {
        productId = order.productName; // Fallback
      }
      
      final domain.Order domainOrder = domain.Order(
        id: order.id,
        productId: productId,
        productName: order.productName,
        quantity: order.quantity,
        departmentId: order.departmentId,
        status: status,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );
      
      final result = await _orderRepository.updateOrder(domainOrder);
      
      return await result.fold(
        (failure) async {
          debugPrint('❌ Failed to update order status in Supabase: ${failure.message}');
          // Supabase'ga yozish xato bo'lsa ham Hive'ga yozishga harakat qilamiz
          try {
            order.status = status;
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.put(order.id, order);
            return true; // Hive'ga yozildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (updatedOrder) async {
          // 2. Hive'ga ham yozish (offline cache uchun)
          try {
            order.status = status;
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.put(order.id, order);
            debugPrint('✅ Order status updated in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Order status updated in Supabase but failed to save to Hive: $e');
            return true; // Supabase'ga yozildi, bu asosiy
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in updateOrderStatus: $e');
      return false;
    }
  }

  /// Order completion - stock reduction bilan
  /// Bu funksiya order complete bo'lganda partlarning miqdorini kamaytiradi
  /// [isForce] true bo'lsa, qismlar yetishmasa ham tugatadi (faqat borini ayiradi)
  Future<bool> completeOrder(data.Order order, {bool isForce = false}) async {
    if (order.status == 'completed') {
      return false; // Already completed
    }

    // Product topish
    Product? product;
    try {
      product = _productService.getAllProducts().firstWhere(
        (p) => p.name == order.productName,
        orElse: () => Product(
          id: '',
          name: order.productName,
          parts: {},
          departmentId: order.departmentId,
        ),
      );
    } catch (e) {
      return false; // Product topilmadi
    }

    if (product.id.isEmpty) {
      return false; // Product not found
    }

    final partsToUpdate = <String, int>{}; // partId -> quantity to decrease
    final missingParts = <String>[]; // Yetishmagan qismlar nomi
    
    for (var entry in product.parts.entries) {
      final partId = entry.key;
      final qtyPerProduct = entry.value;
      final totalQty = qtyPerProduct * order.quantity;
      
      final part = _partService.getPartById(partId);
      if (part == null) {
        if (isForce) {
          missingParts.add('Noma\'lum qism ($partId)');
          continue;
        }
        return false; // Part not found
      }

      if (part.quantity < totalQty) {
        if (isForce) {
          // Force bo'lsa - borini ayiradi, yoki shunchaki skip qiladi
          missingParts.add('${part.name} (-${totalQty - part.quantity})');
          if (part.quantity > 0) {
            partsToUpdate[partId] = part.quantity; // Borini ayirib yuboramiz
          }
          continue;
        }
        return false; // Insufficient stock
      }

      partsToUpdate[partId] = totalQty;
    }

    // Update parts in batch
    if (partsToUpdate.isNotEmpty) {
      final batchResult = await _partService.decreaseQuantitiesBatch(partsToUpdate);
      if (!batchResult) {
        debugPrint('❌ Failed to update parts in batch');
        return false;
      }
    }

    // Order statusini yangilash
    order.status = 'completed';
    order.completedAt = DateTime.now();
    
    // Agar force bo'lgan bo'lsa, notes ga yozib qo'yamiz
    if (isForce && missingParts.isNotEmpty) {
      final shortageNote = '⚠️ Majburiy tugatildi. Yetishmagan qismlar: ${missingParts.join(', ')}';
      order.notes = order.notes != null ? '${order.notes}\n$shortageNote' : shortageNote;
    }

    // Calculate duration if startedAt exists
    if (order.startedAt != null) {
      final diff = order.completedAt!.difference(order.startedAt!);
      order.durationHours = diff.inMinutes / 60.0;
    }
    
    // Supabase va Hive'ni yangilash
    final updateResult = await updateOrder(order);
    if (!updateResult) {
      final box = await Hive.openBox<data.Order>(_orderBoxName);
      await box.put(order.id, order);
    }

    return true;
  }

  /// Parts availability tekshirish - order yaratishdan oldin
  /// FIX: firstWhere xatolikni oldini olish
  bool checkPartsAvailability(String productName, int quantity) {
    Product? product;
    try {
      product = _productService.getAllProducts().firstWhere(
        (p) => p.name == productName,
        orElse: () => Product(id: '', name: '', parts: {}, departmentId: ''),
      );
    } catch (e) {
      return false; // Product topilmadi
    }

    if (product.id.isEmpty) return false;

    for (var entry in product.parts.entries) {
      final partId = entry.key;
      final qtyPerProduct = entry.value;
      final requiredQty = qtyPerProduct * quantity;
      
      final part = _partService.getPartById(partId);
      if (part == null || part.quantity < requiredQty) {
        return false;
      }
    }

    return true;
  }

  /// Qidiruv - product nomi yoki status bo'yicha
  List<data.Order> searchOrders(String query) {
    if (query.isEmpty) return getAllOrders();
    
    final lowerQuery = query.toLowerCase();
    return getAllOrders().where((order) {
      return order.productName.toLowerCase().contains(lowerQuery) ||
             order.status.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Status bo'yicha filtrlash
  List<data.Order> filterByStatus(String? status) {
    if (status == null || status.isEmpty) return getAllOrders();
    return getAllOrders().where((order) => order.status == status).toList();
  }

  /// Department bo'yicha filtrlash
  List<data.Order> filterByDepartment(String? departmentId) {
    if (departmentId == null || departmentId.isEmpty) return getAllOrders();
    return getAllOrders().where((order) => order.departmentId == departmentId).toList();
  }

  /// Qidiruv va filtrlash birga
  List<data.Order> searchAndFilterOrders({
    String? query,
    String? status,
    String? departmentId,
  }) {
    List<data.Order> orders = getAllOrders();

    // Status bo'yicha filtrlash
    if (status != null && status.isNotEmpty) {
      orders = orders.where((o) => o.status == status).toList();
    }

    // Department bo'yicha filtrlash
    if (departmentId != null && departmentId.isNotEmpty) {
      orders = orders.where((o) => o.departmentId == departmentId).toList();
    }

    // Qidiruv
    if (query != null && query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      orders = orders.where((o) {
        return o.productName.toLowerCase().contains(lowerQuery) ||
               o.status.toLowerCase().contains(lowerQuery);
      }).toList();
    }

    return orders;
  }

  /// Tartiblash - sana, status yoki product nomi bo'yicha
  List<data.Order> sortOrders(List<data.Order> orders, {
    bool byDate = true,
    bool ascending = false, // Default: newest first
  }) {
    final sorted = List<data.Order>.from(orders);
    sorted.sort((a, b) {
      if (byDate) {
        final comparison = a.createdAt.compareTo(b.createdAt);
        return ascending ? comparison : -comparison;
      } else {
        final comparison = a.productName.compareTo(b.productName);
        return ascending ? comparison : -comparison;
      }
    });
    return sorted;
  }

  /// Order lifecycle methods - Yangi qo'shilayotgan metodlar

  /// Orderga worker tayinlash
  /// Repository pattern - works for both web and mobile
  Future<bool> assignWorkerToOrder(String orderId, String workerId) async {
    try {
      final order = getOrderById(orderId);
      if (order == null) {
        return false;
      }
      
      // ProductId topish
      String? productId;
      try {
        final products = _productService.getAllProducts();
        final product = products.firstWhere(
          (p) => p.name == order.productName,
          orElse: () => throw StateError('Product not found'),
        );
        productId = product.id;
      } catch (e) {
        productId = order.productName; // Fallback
      }
      
      // Domain Order yaratish
      final domainOrder = domain.Order(
        id: order.id,
        productId: productId,
        productName: order.productName,
        quantity: order.quantity,
        departmentId: order.departmentId,
        status: order.status,
        workerId: workerId, // Worker ID qo'shildi
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Repository orqali yangilash
      final result = await _orderRepository.updateOrder(domainOrder);
      
      return result.fold(
        (failure) {
          debugPrint('❌ Failed to assign worker to order: ${failure.message}');
          return false;
        },
        (updatedOrder) async {
          // Hive'ga ham saqlash
          try {
            order.workerId = workerId; // Yangi maydonni yangilash
            order.updatedAt = DateTime.now(); // Yangilangan vaqtini belgilash
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.put(order.id, order);
            debugPrint('✅ Worker assigned to order in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Worker assigned to order in Supabase but failed to save to Hive: $e');
            return true;
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in assignWorkerToOrder: $e');
      return false;
    }
  }

  /// Start order with time tracking (when assigned to worker)
  Future<bool> startOrderWithTimeTracking(String orderId, String workerId) async {
    try {
      final order = getOrderById(orderId);
      if (order == null) {
        return false;
      }
      
      // Statusni tekshirish
      if (order.status != 'pending') {
        debugPrint('⚠️ Order status is not pending: ${order.status}');
        return false;
      }
      
      // ProductId topish
      String? productId;
      try {
        final products = _productService.getAllProducts();
        final product = products.firstWhere(
          (p) => p.name == order.productName,
          orElse: () => throw StateError('Product not found'),
        );
        productId = product.id;
      } catch (e) {
        productId = order.productName; // Fallback
      }
      
      // Domain Order yaratish
      final domainOrder = domain.Order(
        id: order.id,
        productId: productId,
        productName: order.productName,
        quantity: order.quantity,
        departmentId: order.departmentId,
        status: 'in_progress', // Statusni yangilash
        workerId: workerId, // Worker ID qo'shish
        startedAt: DateTime.now(), // Boshlangan vaqtni belgilash
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Repository orqali yangilash
      final result = await _orderRepository.updateOrder(domainOrder);
      
      return await result.fold(
        (failure) {
          debugPrint('❌ Failed to start order with time tracking: ${failure.message}');
          return false;
        },
        (updatedOrder) async {
          // Hive'ga ham saqlash
          try {
            order.status = 'in_progress';
            order.workerId = workerId;
            order.startedAt = DateTime.now(); // Boshlangan vaqtni belgilash
            order.updatedAt = DateTime.now();
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.put(order.id, order);
            debugPrint('✅ Order started with time tracking successfully in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Order started with time tracking in Supabase but failed to save to Hive: $e');
            return true;
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in startOrderWithTimeTracking: $e');
      return false;
    }
  }

  /// Order statusini 'in_progress' ga o'tkazish (worker tayinlanganda)
  Future<bool> startOrder(String orderId, String workerId) async {
    try {
      final order = getOrderById(orderId);
      if (order == null) {
        return false;
      }
      
      // Statusni tekshirish
      if (order.status != 'pending') {
        debugPrint('⚠️ Order status is not pending: ${order.status}');
        return false;
      }
      
      // ProductId topish
      String? productId;
      try {
        final products = _productService.getAllProducts();
        final product = products.firstWhere(
          (p) => p.name == order.productName,
          orElse: () => throw StateError('Product not found'),
        );
        productId = product.id;
      } catch (e) {
        productId = order.productName; // Fallback
      }
      
      // Domain Order yaratish
      final domainOrder = domain.Order(
        id: order.id,
        productId: productId,
        productName: order.productName,
        quantity: order.quantity,
        departmentId: order.departmentId,
        status: 'in_progress', // Statusni yangilash
        workerId: workerId, // Worker ID qo'shish
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Repository orqali yangilash
      final result = await _orderRepository.updateOrder(domainOrder);
      
      return await result.fold(
        (failure) async {
          debugPrint('❌ Failed to start order: ${failure.message}');
          return false;
        },
        (updatedOrder) async {
          // Hive'ga ham saqlash
          try {
            order.status = 'in_progress';
            order.workerId = workerId;
            order.updatedAt = DateTime.now();
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.put(order.id, order);
            debugPrint('✅ Order started successfully in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Order started in Supabase but failed to save to Hive: $e');
            return true;
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in startOrder: $e');
      return false;
    }
  }

  /// Qisman (partial) completion - order bajarilishini qismman belgilash
  Future<bool> partiallyCompleteOrder(String orderId, int completedQuantity) async {
    try {
      final order = getOrderById(orderId);
      if (order == null) {
        return false;
      }
      
      // Statusni tekshirish - faqat in_progress yoki partially completed bo'lsa mumkin
      if (order.status != 'in_progress' && order.status != 'partially_completed') {
        debugPrint('⚠️ Order status is not in_progress or partially_completed: ${order.status}');
        return false;
      }
      
      // Completed miqdorini tekshirish
      if (completedQuantity <= 0 || completedQuantity >= order.quantity) {
        debugPrint('⚠️ Invalid completed quantity: $completedQuantity (total: ${order.quantity})');
        return false;
      }
      
      // ProductId topish
      String? productId;
      try {
        final products = _productService.getAllProducts();
        final product = products.firstWhere(
          (p) => p.name == order.productName,
          orElse: () => throw StateError('Product not found'),
        );
        productId = product.id;
      } catch (e) {
        productId = order.productName; // Fallback
      }
      
      // Domain Order yaratish
      final domainOrder = domain.Order(
        id: order.id,
        productId: productId,
        productName: order.productName,
        quantity: order.quantity,
        completedQuantity: completedQuantity, // Completed miqdorini yangilash
        departmentId: order.departmentId,
        status: 'partially_completed', // Statusni partially_completed qilish
        workerId: order.workerId,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Repository orqali yangilash
      final result = await _orderRepository.updateOrder(domainOrder);
      
      return await result.fold(
        (failure) async {
          debugPrint('❌ Failed to partially complete order: ${failure.message}');
          return false;
        },
        (updatedOrder) async {
          // Hive'ga ham saqlash
          try {
            order.status = 'partially_completed';
            order.completedQuantity = completedQuantity;
            order.updatedAt = DateTime.now();
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.put(order.id, order);
            debugPrint('✅ Order partially completed successfully in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Order partially completed in Supabase but failed to save to Hive: $e');
            return true;
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in partiallyCompleteOrder: $e');
      return false;
    }
  }

  /// Orderga qo'shimcha miqdor qo'shish (partial completion davom ettirish)
  Future<bool> addPartialCompletion(String orderId, int additionalQuantity) async {
    try {
      final order = getOrderById(orderId);
      if (order == null) {
        return false;
      }
      
      // Statusni tekshirish
      if (order.status != 'partially_completed') {
        debugPrint('⚠️ Order status is not partially_completed: ${order.status}');
        return false;
      }
      
      // Yangi completed miqdorini hisoblash
      final newCompletedQuantity = order.completedQuantity + additionalQuantity;
      
      // Cheklov: completed miqdori umumiy miqdordan oshmasligi kerak
      if (newCompletedQuantity > order.quantity) {
        debugPrint('⚠️ New completed quantity exceeds total quantity: $newCompletedQuantity > ${order.quantity}');
        return false;
      }
      
      // ProductId topish
      String? productId;
      try {
        final products = _productService.getAllProducts();
        final product = products.firstWhere(
          (p) => p.name == order.productName,
          orElse: () => throw StateError('Product not found'),
        );
        productId = product.id;
      } catch (e) {
        productId = order.productName; // Fallback
      }
      
      // Statusni aniqlash - agar barchasi bajarilgan bo'lsa 'completed' qilish
      final newStatus = newCompletedQuantity >= order.quantity ? 'completed' : 'partially_completed';
      
      // Domain Order yaratish
      final domainOrder = domain.Order(
        id: order.id,
        productId: productId,
        productName: order.productName,
        quantity: order.quantity,
        completedQuantity: newCompletedQuantity, // Yangilangan completed miqdor
        departmentId: order.departmentId,
        status: newStatus, // Statusni yangilash
        workerId: order.workerId,
        completedBy: newStatus == 'completed' ? AuthStateService().currentUser?.id : null, // Agar to'liq completed bo'lsa, kim tugatganini belgilash
        completedAt: newStatus == 'completed' ? DateTime.now() : null, // Completed vaqtini belgilash
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Repository orqali yangilash
      final result = await _orderRepository.updateOrder(domainOrder);
      
      return await result.fold(
        (failure) async {
          debugPrint('❌ Failed to add partial completion: ${failure.message}');
          return false;
        },
        (updatedOrder) async {
          // Hive'ga ham saqlash
          try {
            order.status = newStatus;
            order.completedQuantity = newCompletedQuantity;
            order.completedBy = newStatus == 'completed' ? AuthStateService().currentUser?.id : null;
            order.completedAt = newStatus == 'completed' ? DateTime.now() : null;
            order.updatedAt = DateTime.now();
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.put(order.id, order);
            debugPrint('✅ Partial completion added successfully in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Partial completion added in Supabase but failed to save to Hive: $e');
            return true;
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in addPartialCompletion: $e');
      return false;
    }
  }

  /// Order rejection - buyurtmani rad etish
  Future<bool> rejectOrder(String orderId, String reason) async {
    try {
      final order = getOrderById(orderId);
      if (order == null) {
        return false;
      }
      
      // ProductId topish
      String? productId;
      try {
        final products = _productService.getAllProducts();
        final product = products.firstWhere(
          (p) => p.name == order.productName,
          orElse: () => throw StateError('Product not found'),
        );
        productId = product.id;
      } catch (e) {
        productId = order.productName; // Fallback
      }
      
      // Domain Order yaratish
      final domainOrder = domain.Order(
        id: order.id,
        productId: productId,
        productName: order.productName,
        quantity: order.quantity,
        departmentId: order.departmentId,
        status: 'rejected', // Statusni rejected qilish
        notes: reason, // Rad etish sababini saqlash
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Repository orqali yangilash
      final result = await _orderRepository.updateOrder(domainOrder);
      
      return await result.fold(
        (failure) async {
          debugPrint('❌ Failed to reject order: ${failure.message}');
          return false;
        },
        (updatedOrder) async {
          // Hive'ga ham saqlash
          try {
            order.status = 'rejected';
            order.notes = reason;
            order.updatedAt = DateTime.now();
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.put(order.id, order);
            debugPrint('✅ Order rejected successfully in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Order rejected in Supabase but failed to save to Hive: $e');
            return true;
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in rejectOrder: $e');
      return false;
    }
  }

  /// Get workers - foydalanuvchilarni worker sifatida olish
  Future<List<user_domain.User>> getWorkers() async {
    try {
      // UserRepository orqali barcha foydalanuvchilarni olish
      final userRepository = ServiceLocator.instance.userRepository;
      final result = await userRepository.getAllUsers();
      
      return result.fold(
        (failure) {
          debugPrint('❌ Failed to get users: ${failure.message}');
          return <user_domain.User>[];
        },
        (users) {
          // Faqat worker va manager larni qaytarish
          return users.where((user) => user.isWorker || user.isManager).toList();
        },
      );
    } catch (e) {
      debugPrint('❌ Error getting workers: $e');
      return [];
    }
  }

  /// Get orders by worker - workerga tayinlangan buyurtmalarni olish
  List<data.Order> getOrdersByWorker(String workerId) {
    try {
      return getAllOrders().where((order) => order.workerId == workerId).toList();
    } catch (e) {
      debugPrint('❌ Error getting orders by worker: $e');
      return [];
    }
  }

  /// Get orders by status - status bo'yicha buyurtmalarni olish
  List<data.Order> getOrdersByStatus(String status) {
    try {
      return getAllOrders().where((order) => order.status == status).toList();
    } catch (e) {
      debugPrint('❌ Error getting orders by status: $e');
      return [];
    }
  }

  /// Get pending orders - kutayotgan buyurtmalarni olish
  List<data.Order> getPendingOrders() {
    return getOrdersByStatus('pending');
  }

  /// Get in progress orders - bajarilayotgan buyurtmalarni olish
  List<data.Order> getInProgressOrders({int limit = 10}) {
    try {
      final orders = getAllOrders()
          .where((order) => order.status == 'in_progress' || order.status == 'partially_completed')
          .toList();
      
      // Sort by start time (most recent first)
      orders.sort((a, b) {
        final timeA = a.startedAt ?? a.updatedAt ?? a.createdAt;
        final timeB = b.startedAt ?? b.updatedAt ?? b.createdAt;
        return timeB.compareTo(timeA); // Descending order (newest first)
      });
      
      return orders.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error getting in-progress orders: $e');
      return [];
    }
  }

  /// Get completed orders - tugallangan buyurtmalarni olish
  List<data.Order> getCompletedOrders() {
    return getOrdersByStatus('completed');
  }

  /// Get rejected orders - rad etilgan buyurtmalarni olish
  List<data.Order> getRejectedOrders() {
    return getOrdersByStatus('rejected');
  }

  /// Get partially completed orders - qisman tugallangan buyurtmalarni olish
  List<data.Order> getPartiallyCompletedOrders() {
    try {
      return getAllOrders().where((order) => order.status == 'partially_completed').toList();
    } catch (e) {
      debugPrint('❌ Error getting partially completed orders: $e');
      return [];
    }
  }

  /// Order deletion methods - Secure implementation with audit trail

  /// Soft delete order (manager and boss can use this)Order nomi ochilgan sanasi product qancha tanlangani
  /// This marks order as deleted but keeps it in database for audit
  Future<bool> softDeleteOrder(String orderId, {String? reason}) async {
    try {
      // Permission check
      final currentUser = AuthStateService().currentUser;
      if (currentUser == null || (!currentUser.isManager && !currentUser.isBoss)) {
        debugPrint('❌ User does not have permission to delete orders');
        return false;
      }
      
      // Use repository to soft delete
      final result = await _orderRepository.softDeleteOrder(orderId, reason: reason);
      
      return result.fold(
        (failure) {
          debugPrint('❌ Failed to soft delete order: ${failure.message}');
          return false;
        },
        (success) {
          if (success) {
            debugPrint('✅ Order soft deleted successfully');
            return true;
          } else {
            debugPrint('⚠️ Order not found or already deleted');
            return false;
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in softDeleteOrder: $e');
      return false;
    }
  }

  /// Restore deleted order (boss only)
  Future<bool> restoreOrder(String orderId) async {
    try {
      // Permission check - only boss
      final currentUser = AuthStateService().currentUser;
      if (currentUser == null || !currentUser.isBoss) {
        debugPrint('❌ Only boss can restore deleted orders');
        return false;
      }
      
      // Use repository to restore
      final result = await _orderRepository.restoreOrder(orderId);
      
      return result.fold(
        (failure) {
          debugPrint('❌ Failed to restore order: ${failure.message}');
          return false;
        },
        (success) {
          if (success) {
            debugPrint('✅ Order restored successfully');
            return true;
          } else {
            debugPrint('⚠️ Order not found or not deleted');
            return false;
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in restoreOrder: $e');
      return false;
    }
  }

  /// Permanently delete order (boss only) - USE WITH CAUTION
  /// This completely removes the order from database
  Future<bool> permanentlyDeleteOrder(String orderId) async {
    try {
      // Permission check - only boss
      final currentUser = AuthStateService().currentUser;
      if (currentUser == null || !currentUser.isBoss) {
        debugPrint('❌ Only boss can permanently delete orders');
        return false;
      }
      
      // Confirmation required in UI before calling this
      final result = await _orderRepository.permanentlyDeleteOrder(orderId);
      
      return result.fold(
        (failure) {
          debugPrint('❌ Failed to permanently delete order: ${failure.message}');
          return false;
        },
        (success) {
          if (success) {
            debugPrint('✅ Order permanently deleted');
            return true;
          } else {
            debugPrint('⚠️ Order not found');
            return false;
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in permanentlyDeleteOrder: $e');
      return false;
    }
  }

  /// Get deleted orders (boss only)
  Future<List<domain.Order>> getDeletedOrders() async {
    try {
      // Permission check - only boss
      final currentUser = AuthStateService().currentUser;
      if (currentUser == null || !currentUser.isBoss) {
        debugPrint('❌ Only boss can view deleted orders');
        return [];
      }
      
      // Use repository to get deleted orders
      final result = await _orderRepository.getDeletedOrders();
      
      return result.fold(
        (failure) {
          debugPrint('❌ Failed to get deleted orders: ${failure.message}');
          return [];
        },
        (orders) => orders,
      );
    } catch (e) {
      debugPrint('❌ Error in getDeletedOrders: $e');
      return [];
    }
  }

  /// Complete order with time tracking (when fully completed)
  Future<bool> completeOrderWithTimeTracking(domain.Order order) async {
    if (order.status == 'completed') {
      return false; // Already completed
    }

    // Check if order is fully completed
    if (order.completedQuantity < order.quantity) {
      debugPrint('⚠️ Order is not fully completed yet: ${order.completedQuantity}/${order.quantity}');
      return false;
    }

    // Product topish
    Product? product;
    try {
      product = _productService.getAllProducts().firstWhere(
        (p) => p.name == order.productName,
        orElse: () => Product(
          id: '',
          name: order.productName,
          parts: {},
          departmentId: order.departmentId,
        ),
      );
    } catch (e) {
      return false; // Product not found
    }

    if (product.id.isEmpty) {
      return false; // Product not found
    }

    // FIX: Barcha partlarni bir marta tekshirish (performance)
    final partsToUpdate = <String, int>{}; // partId -> quantity to decrease
    
    for (var entry in product.parts.entries) {
      final partId = entry.key;
      final qtyPerProduct = entry.value;
      final totalQty = qtyPerProduct * order.quantity;
      
      final part = _partService.getPartById(partId);
      if (part == null) {
        return false; // Part not found
      }

      if (part.quantity < totalQty) {
        return false; // Insufficient stock
      }

      // Barcha o'zgarishlarni to'plab olish
      partsToUpdate[partId] = totalQty;
    }

    // OPTIMIZATION: Barcha partlarni bir marta batch update qilish (tezroq)
    final batchResult = await _partService.decreaseQuantitiesBatch(partsToUpdate);
    if (!batchResult) {
      debugPrint('❌ Failed to update parts in batch');
      return false;
    }

    // Calculate duration if startedAt is available
    double? durationHours;
    if (order.startedAt != null) {
      final difference = DateTime.now().difference(order.startedAt!);
      durationHours = difference.inMinutes / 60.0; // Convert minutes to hours
    }

    // Order statusini yangilash (Supabase'ga ham yozish)
    // Convert domain order to data order
    final dataOrder = getOrderById(order.id);
    if (dataOrder != null) {
      dataOrder.status = 'completed';
      dataOrder.completedAt = DateTime.now(); // Tugallangan vaqtni belgilash
      dataOrder.completedBy = AuthStateService().currentUser?.id; // Kim tugatgan
      dataOrder.durationHours = durationHours; // Duration qo'shish
      
      // FIX: Supabase'ga ham yozish (realtime sync uchun)
      final updateResult = await updateOrder(dataOrder);
      if (!updateResult) {
        // Supabase'ga yozish xato bo'lsa ham Hive'ga yozish
        final box = await Hive.openBox<data.Order>(_orderBoxName);
        await box.put(dataOrder.id, dataOrder);
      }
    }

    return true;
  }

  /// Get orders with time tracking statistics
  List<domain.Order> getOrdersWithTimeTracking() {
    try {
      return getAllOrders().map((dataOrder) {
        // Convert data order to domain order with time tracking fields
        return domain.Order(
          id: dataOrder.id,
          productId: dataOrder.productName, // Fallback
          productName: dataOrder.productName,
          quantity: dataOrder.quantity,
          completedQuantity: dataOrder.completedQuantity,
          departmentId: dataOrder.departmentId,
          status: dataOrder.status,
          workerId: dataOrder.workerId,
          completedBy: dataOrder.completedBy,
          createdBy: null, // Not available in data model
          approvedBy: null, // Not available in data model
          soldTo: dataOrder.soldTo,
          notes: dataOrder.notes,
          partsRequired: dataOrder.partsRequired != null 
              ? Map<String, int>.from(dataOrder.partsRequired as Map) 
              : null,
          createdAt: dataOrder.createdAt,
          updatedAt: dataOrder.updatedAt,
          completedAt: dataOrder.completedAt,
          startedAt: dataOrder.startedAt,
          durationHours: dataOrder.durationHours,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting orders with time tracking: $e');
      return [];
    }
  }

  /// Calculate average completion time for orders
  double getAverageCompletionTime() {
    try {
      final orders = getOrdersWithTimeTracking().where((order) => 
          order.hasStarted && order.isFullyCompleted).toList();
      
      if (orders.isEmpty) return 0.0;
      
      double totalDuration = 0.0;
      for (final order in orders) {
        final duration = order.getDurationInHours();
        if (duration != null) {
          totalDuration += duration;
        }
      }
      
      return totalDuration / orders.length;
    } catch (e) {
      debugPrint('❌ Error calculating average completion time: $e');
      return 0.0;
    }
  }

  /// Assign courier to order with specific quantity
  Future<bool> assignCourierToOrder(String orderId, String courierId, int quantity) async {
    try {
      final order = getOrderById(orderId);
      if (order == null) {
        return false;
      }
      
      // Check if quantity is valid
      if (quantity <= 0 || quantity > order.quantity) {
        debugPrint('⚠️ Invalid quantity for courier assignment: $quantity (order quantity: ${order.quantity})');
        return false;
      }
      
      // Check if order has been taken by another courier
      // We'll store this information in the notes field temporarily
      String updatedNotes = '';
      if (order.notes != null && order.notes!.isNotEmpty) {
        updatedNotes = '${order.notes!}\nCourier $courierId took $quantity items';
      } else {
        updatedNotes = 'Courier $courierId took $quantity items';
      }
      
      // Update order status if needed
      String newStatus = order.status;
      if (order.status == 'pending') {
        newStatus = 'in_progress';
      }
      
      // ProductId topish
      String? productId;
      try {
        final products = _productService.getAllProducts();
        final product = products.firstWhere(
          (p) => p.name == order.productName,
          orElse: () => throw StateError('Product not found'),
        );
        productId = product.id;
      } catch (e) {
        productId = order.productName; // Fallback
      }
      
      // Domain Order yaratish
      final domainOrder = domain.Order(
        id: order.id,
        productId: productId,
        productName: order.productName,
        quantity: order.quantity,
        completedQuantity: order.completedQuantity,
        departmentId: order.departmentId,
        status: newStatus,
        workerId: order.workerId ?? courierId, // Set courier as worker
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
        notes: updatedNotes,
      );
      
      final result = await _orderRepository.updateOrder(domainOrder);
      
      return await result.fold(
        (failure) async {
          debugPrint('❌ Failed to assign courier to order: ${failure.message}');
          return false;
        },
        (updatedOrder) async {
          // Hive'ga ham saqlash
          try {
            order.workerId = order.workerId ?? courierId;
            order.notes = updatedNotes;
            order.status = newStatus;
            order.updatedAt = DateTime.now();
            final box = await Hive.openBox<data.Order>(_orderBoxName);
            await box.put(order.id, order);
            debugPrint('✅ Courier assigned to order successfully in both Supabase and Hive');
            
            // Send notification to manager about ready orders
            TelegramNotificationService.sendReadyOrderNotification(quantity, 'Courier');
            
            return true;
          } catch (e) {
            debugPrint('⚠️ Courier assigned to order in Supabase but failed to save to Hive: $e');
            
            // Still send notification even if Hive save fails
            TelegramNotificationService.sendReadyOrderNotification(quantity, 'Courier');
            
            return true;
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in assignCourierToOrder: $e');
      return false;
    }
  }

  /// Get orders assigned to a specific courier
  List<data.Order> getOrdersByCourier(String courierId) {
    try {
      return getAllOrders().where((order) => order.workerId == courierId).toList();
    } catch (e) {
      debugPrint('❌ Error getting orders by courier: $e');
      return [];
    }
  }

  /// Complete order by courier and deduct parts
  Future<bool> completeOrderByCourier(data.Order order) async {
    if (order.status == 'completed') {
      return false; // Already completed
    }

    // Product topish
    Product? product;
    try {
      product = _productService.getAllProducts().firstWhere(
        (p) => p.name == order.productName,
        orElse: () => Product(
          id: '',
          name: order.productName,
          parts: {},
          departmentId: order.departmentId,
        ),
      );
    } catch (e) {
      return false; // Product not found
    }

    if (product.id.isEmpty) {
      return false; // Product not found
    }

    // Calculate parts to deduct based on completed quantity
    final completedQty = order.completedQuantity > 0 ? order.completedQuantity : order.quantity;
    
    // FIX: Barcha partlarni bir marta tekshirish (performance)
    final partsToUpdate = <String, int>{}; // partId -> quantity to decrease
    
    for (var entry in product.parts.entries) {
      final partId = entry.key;
      final qtyPerProduct = entry.value;
      final totalQty = qtyPerProduct * completedQty;
      
      final part = _partService.getPartById(partId);
      if (part == null) {
        return false; // Part not found
      }

      if (part.quantity < totalQty) {
        return false; // Insufficient stock
      }

      // Barcha o'zgarishlarni to'plab olish
      partsToUpdate[partId] = totalQty;
    }

    // OPTIMIZATION: Barcha partlarni bir marta batch update qilish (tezroq)
    final batchResult = await _partService.decreaseQuantitiesBatch(partsToUpdate);
    if (!batchResult) {
      debugPrint('❌ Failed to update parts in batch');
      return false;
    }

    // Order statusini yangilash (Supabase'ga ham yozish)
    order.status = 'completed';
    
    // FIX: Supabase'ga ham yozish (realtime sync uchun)
    final updateResult = await updateOrder(order);
    if (!updateResult) {
      // Supabase'ga yozish xato bo'lsa ham Hive'ga yozish
      final box = await Hive.openBox<data.Order>(_orderBoxName);
      await box.put(order.id, order);
    }

    // Send notification about order completion
    TelegramNotificationService.sendOrderCompletedNotification(order.productName, completedQty);

    return true;
  }

  /// Notify manager about ready orders
  void notifyManagerAboutReadyOrders(int count, String courierName) {
    debugPrint('🔔 TELEGRAM NOTIFICATION TO MANAGER: $count ta tayyor, $courierName olib ketishi mumkin');
    // Send notification via Telegram
    TelegramNotificationService.sendReadyOrderNotification(count, courierName);
  }

  /// Get courier analytics - who took how many items
  Map<String, int> getCourierAnalytics() {
    try {
      final orders = getAllOrders().where((order) => 
          order.status == 'completed' && order.workerId != null && order.workerId!.isNotEmpty).toList();
      
      final Map<String, int> analytics = {};
      
      for (final order in orders) {
        final courierId = order.workerId!;
        final completedQty = order.completedQuantity > 0 ? order.completedQuantity : order.quantity;
        
        analytics[courierId] = (analytics[courierId] ?? 0) + completedQty;
      }
      
      return analytics;
    } catch (e) {
      debugPrint('❌ Error getting courier analytics: $e');
      return {};
    }
  }

  /// Get recently completed orders - for showing latest 'ready' notifications
  List<data.Order> getRecentlyCompletedOrders({int limit = 10}) {
    try {
      final orders = getAllOrders()
          .where((order) => order.status == 'completed')
          .toList();
      
      // Sort by completion time (most recent first)
      orders.sort((a, b) {
        final timeA = a.completedAt ?? a.updatedAt ?? a.createdAt;
        final timeB = b.completedAt ?? b.updatedAt ?? b.createdAt;
        return timeB.compareTo(timeA); // Descending order (newest first)
      });
      
      return orders.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error getting recently completed orders: $e');
      return [];
    }
  }

  /// Create order with parts snapshot (for showing shortages in pending state)
  Future<bool> createOrderWithPartsSnapshot({
    required String id,
    required String departmentId,
    required String productName,
    required int quantity,
    String? soldTo,
    String? notes,
  }) async {
    try {
      // Get product to create parts snapshot
      final productService = ProductService();
      final product = productService.getAllProducts().firstWhere(
        (p) => p.name == productName,
        orElse: () => throw StateError('Product not found'),
      );

      // Create parts snapshot (the required parts for this order)
      final partsSnapshot = <String, int>{};
      for (final entry in product.parts.entries) {
        partsSnapshot[entry.key] = entry.value * quantity;
      }

      // Create order with parts snapshot
      final order = data.Order(
        id: id,
        departmentId: departmentId,
        productName: productName,
        quantity: quantity,
        status: 'pending',
        soldTo: soldTo,
        notes: notes,
        partsRequired: partsSnapshot,
        // Initially no taken items
        takenItems: [],
      );

      // Check for parts shortage (handled in addOrder via _sendOrderCreationNotification)
      _checkPartsShortage(product, quantity);
      
      // Even if there are shortages, create the order in pending state
      final result = await addOrder(order);
      
      // Send notification that order is ready
      if (result) {
        TelegramNotificationService.sendReadyOrderNotification(quantity, 'Courier');
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Error creating order with parts snapshot: $e');
      return false;
    }
  }

  /// Check parts shortage for a product
  List<Map<String, dynamic>> _checkPartsShortage(Product product, int quantity) {
    final partService = PartService();
    final shortages = <Map<String, dynamic>>[];
    
    for (final entry in product.parts.entries) {
      final partId = entry.key;
      final part = partService.getPartById(partId);
      if (part != null) {
        final required = entry.value * quantity;
        final available = part.quantity;
        final shortage = required - available;
        
        if (shortage > 0) {
          shortages.add({
            'partId': partId,
            'partName': part.name,
            'required': required,
            'available': available,
            'shortage': shortage,
          });
        }
      }
    }
    
    return shortages;
  }

  /// Add taken item to order
  Future<bool> addTakenItemToOrder({
    required String orderId,
    required String courierId,
    required int quantity,
    String? notes,
  }) async {
    try {
      final order = getOrderById(orderId);
      if (order == null) {
        debugPrint('❌ Order not found: $orderId');
        return false;
      }

      // Import the taken_item model
      final takenItem = TakenItem(
        courierId: courierId,
        quantity: quantity,
        notes: notes,
      );

      // Add to the order's taken items list
      order.takenItems = [...order.takenItems, takenItem];

      // Update the order status to reflect that items are being taken
      if (order.status == 'pending') {
        order.status = 'in_progress';
      }

      // Check if all items have been taken to update the overall completion status
      final totalTaken = order.takenItems.fold(0, (sum, item) => sum + item.quantity);
      if (totalTaken >= order.quantity) {
        order.status = 'completed';
        order.fullyCompletedAt = DateTime.now();
        // Update completedAt if not already set
        order.completedAt ??= DateTime.now();
      }

      // Update the order in both Hive and Supabase
      final box = await Hive.openBox<data.Order>(_orderBoxName);
      await box.put(order.id, order);
      final result = await updateOrder(order);
      if (!result) {
        debugPrint('⚠️ Failed to update order after adding taken item');
      }

      // Send notification about the taken items
      TelegramNotificationService.sendOrderTakenNotification(
        order.productName,
        quantity,
        totalTaken,
        order.quantity,
      );

      return result;
    } catch (e) {
      debugPrint('❌ Error adding taken item to order: $e');
      return false;
    }
  }

  /// Get taken items for an order
  List<TakenItem> getTakenItemsForOrder(String orderId) {
    try {
      final order = getOrderById(orderId);
      if (order == null) {
        return [];
      }
      return order.takenItems;
    } catch (e) {
      debugPrint('❌ Error getting taken items for order $orderId: $e');
      return [];
    }
  }

  /// Get total quantity taken for an order
  int getTotalTakenQuantity(String orderId) {
    try {
      final order = getOrderById(orderId);
      if (order == null) {
        return 0;
      }
      return order.takenItems.fold(0, (sum, item) => sum + item.quantity);
    } catch (e) {
      debugPrint('❌ Error getting total taken quantity for order $orderId: $e');
      return 0;
    }
  }

  /// Check if an order is fully taken
  bool isOrderFullyTaken(String orderId) {
    try {
      final order = getOrderById(orderId);
      if (order == null) {
        return false;
      }
      final totalTaken = getTotalTakenQuantity(orderId);
      return totalTaken >= order.quantity;
    } catch (e) {
      debugPrint('❌ Error checking if order is fully taken $orderId: $e');
      return false;
    }
  }

  /// Get all orders that have been partially or fully taken
  List<data.Order> getOrdersWithTakenItems() {
    try {
      final allOrders = getAllOrders();
      return allOrders.where((order) => order.takenItems.isNotEmpty).toList();
    } catch (e) {
      debugPrint('❌ Error getting orders with taken items: $e');
      return [];
    }
  }

}

