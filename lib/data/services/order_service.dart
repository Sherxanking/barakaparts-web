/// OrderService - Order bilan ishlash uchun business logic
/// 
/// Bu service order CRUD operatsiyalarini, qidiruv, filtrlash, 
/// tartiblash va order completion (stock reduction) funksiyalarini boshqaradi.
import 'package:flutter/foundation.dart';
import '../models/order_model.dart' as data;
import '../models/product_model.dart';
import 'hive_box_service.dart';
import 'product_service.dart';
import 'part_service.dart';
import '../../domain/entities/order.dart' as domain;
import '../../core/di/service_locator.dart';
import '../../core/utils/either.dart';

class OrderService {
  final HiveBoxService _boxService = HiveBoxService();
  final ProductService _productService = ProductService();
  final PartService _partService = PartService();
  
  // Repository for Supabase sync
  final _orderRepository = ServiceLocator.instance.orderRepository;

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
        productId: productId ?? order.id, // Fallback to order.id if product not found
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
        productId: productId ?? order.id,
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
            await order.save();
            return true; // Hive'ga yozildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (updatedOrder) async {
          // 2. Hive'ga ham yozish (offline cache uchun)
          try {
            await order.save();
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
            final order = getOrderById(orderId);
            if (order != null) {
              await order.delete();
              return true; // Hive'dan o'chirildi, lekin sync yo'q
            }
            return false;
          } catch (e) {
            return false;
          }
        },
        (_) async {
          // 2. Hive'dan ham o'chirish (offline cache uchun)
          try {
            final order = getOrderById(orderId);
            if (order != null) {
              await order.delete();
              debugPrint('✅ Order deleted from both Supabase and Hive');
              return true;
            }
            debugPrint('⚠️ Order deleted from Supabase but not found in Hive');
            return true; // Supabase'dan o'chirildi, bu asosiy
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
      final order = getOrderById(orderId);
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
      
      final domainOrder = domain.Order(
        id: order.id,
        productId: productId ?? order.id,
        productName: order.productName,
        quantity: order.quantity,
        departmentId: order.departmentId,
        status: status,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );
      
      final result = await _orderRepository.updateOrder(domainOrder);
      
      return result.fold(
        (failure) {
          debugPrint('❌ Failed to update order status in Supabase: ${failure.message}');
          // Supabase'ga yozish xato bo'lsa ham Hive'ga yozishga harakat qilamiz
          try {
            order.status = status;
            order.save();
            return true; // Hive'ga yozildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (updatedOrder) {
          // 2. Hive'ga ham yozish (offline cache uchun)
          try {
            order.status = status;
            order.save();
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
  Future<bool> completeOrder(data.Order order) async {
    if (order.status == 'completed') {
      return false; // Already completed
    }

    // Product topish
    // FIX: firstWhere xatolikni oldini olish - try-catch qo'shildi
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

    if (product == null || product.id.isEmpty) {
      return false; // Product not found
    }

    // Har bir part uchun miqdorni tekshirish va kamaytirish
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

      // Stock reduction
      await _partService.decreaseQuantity(partId, totalQty);
    }

    // Order statusini yangilash
    order.status = 'completed';
    await order.save();

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

    if (product == null || product.id.isEmpty) return false;

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
}

