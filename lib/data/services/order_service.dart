/// OrderService - Order bilan ishlash uchun business logic
/// 
/// Bu service order CRUD operatsiyalarini, qidiruv, filtrlash, 
/// tartiblash va order completion (stock reduction) funksiyalarini boshqaradi.
import '../models/order_model.dart';
import '../models/product_model.dart';
import 'hive_box_service.dart';
import 'product_service.dart';
import 'part_service.dart';

class OrderService {
  final HiveBoxService _boxService = HiveBoxService();
  final ProductService _productService = ProductService();
  final PartService _partService = PartService();

  /// Barcha orderlarni olish
  /// FIX: Xavfsiz box kirish - xatolik bo'lsa bo'sh ro'yxat qaytarish
  List<Order> getAllOrders() {
    try {
      return _boxService.ordersBox.values.toList();
    } catch (e) {
      // Box ochilmagan yoki xatolik bo'lsa bo'sh ro'yxat qaytarish
      return [];
    }
  }

  /// ID bo'yicha order topish
  Order? getOrderById(String id) {
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
  /// FIX: Xatolikni tutish va xavfsiz qo'shish
  Future<bool> addOrder(Order order) async {
    try {
      await _boxService.ordersBox.add(order);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Order yangilash
  /// FIX: Xatolikni tutish va xavfsiz yangilash
  Future<bool> updateOrder(Order order) async {
    try {
      await order.save();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Order o'chirish - ID bo'yicha
  /// FIX: Xatolikni tutish va xavfsiz o'chirish
  Future<bool> deleteOrderById(String orderId) async {
    try {
      final order = getOrderById(orderId);
      if (order != null) {
        await order.delete();
        return true;
      }
      return false;
    } catch (e) {
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
  Future<void> updateOrderStatus(String orderId, String status) async {
    final order = getOrderById(orderId);
    if (order != null) {
      order.status = status;
      await order.save();
    }
  }

  /// Order completion - stock reduction bilan
  /// Bu funksiya order complete bo'lganda partlarning miqdorini kamaytiradi
  Future<bool> completeOrder(Order order) async {
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
  List<Order> searchOrders(String query) {
    if (query.isEmpty) return getAllOrders();
    
    final lowerQuery = query.toLowerCase();
    return getAllOrders().where((order) {
      return order.productName.toLowerCase().contains(lowerQuery) ||
             order.status.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Status bo'yicha filtrlash
  List<Order> filterByStatus(String? status) {
    if (status == null || status.isEmpty) return getAllOrders();
    return getAllOrders().where((order) => order.status == status).toList();
  }

  /// Department bo'yicha filtrlash
  List<Order> filterByDepartment(String? departmentId) {
    if (departmentId == null || departmentId.isEmpty) return getAllOrders();
    return getAllOrders().where((order) => order.departmentId == departmentId).toList();
  }

  /// Qidiruv va filtrlash birga
  List<Order> searchAndFilterOrders({
    String? query,
    String? status,
    String? departmentId,
  }) {
    List<Order> orders = getAllOrders();

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
  List<Order> sortOrders(List<Order> orders, {
    bool byDate = true,
    bool ascending = false, // Default: newest first
  }) {
    final sorted = List<Order>.from(orders);
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

