/// Hive Order Cache
/// 
/// MVP: Simple cache implementation for offline support
/// Stores Order entities in Hive for offline access

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/order.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

class HiveOrderCache {
  static const String _boxName = 'ordersCache';
  Box<Map>? _box;

  /// Initialize cache box
  Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<Map>(_boxName);
      return;
    }
    _box = await Hive.openBox<Map>(_boxName);
  }

  /// Get cached orders
  Future<Either<Failure, List<Order>>> getAllOrders() async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      final orders = <Order>[];
      
      for (var key in box.keys) {
        final data = box.get(key) as Map<String, dynamic>?;
        if (data != null) {
          try {
            orders.add(_mapToOrder(data));
          } catch (e) {
            // Skip invalid entries
            continue;
          }
        }
      }
      
      return Right(orders);
    } catch (e) {
      return Left(CacheFailure('Failed to get cached orders: $e'));
    }
  }

  /// Save orders to cache
  Future<void> saveOrders(List<Order> orders) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.clear();
      
      for (var order in orders) {
        await box.put(order.id, _orderToMap(order));
      }
    } catch (e) {
      // Cache errors should not break the app
      debugPrint('⚠️ Cache save error: $e');
    }
  }

  /// Save single order to cache
  Future<void> saveOrder(Order order) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.put(order.id, _orderToMap(order));
    } catch (e) {
      debugPrint('⚠️ Cache update error: $e');
    }
  }

  /// Delete order from cache
  Future<void> deleteOrder(String orderId) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.delete(orderId);
    } catch (e) {
      debugPrint('⚠️ Cache delete error: $e');
    }
  }

  /// Convert Order entity to Map for Hive storage
  Map<String, dynamic> _orderToMap(Order order) {
    return {
      'id': order.id,
      'productId': order.productId,
      'productName': order.productName,
      'quantity': order.quantity,
      'departmentId': order.departmentId,
      'status': order.status,
      'createdBy': order.createdBy,
      'approvedBy': order.approvedBy,
      'createdAt': order.createdAt.toIso8601String(),
      'updatedAt': order.updatedAt?.toIso8601String(),
    };
  }

  /// Convert Map from Hive to Order entity
  Order _mapToOrder(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      quantity: map['quantity'] as int,
      departmentId: map['departmentId'] as String,
      status: map['status'] as String,
      createdBy: map['createdBy'] as String?,
      approvedBy: map['approvedBy'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }
}




