import 'package:flutter/foundation.dart';
import '../models/taken_item.dart';
import '../models/order_model.dart' as data;
import 'order_service.dart';
import '../../core/services/telegram_notification_service.dart';

class TakenItemService {
  final OrderService _orderService = OrderService();

  /// Add a taken item to an order
  Future<bool> addTakenItem({
    required String orderId,
    required String courierId,
    required int quantity,
    String? notes,
  }) async {
    try {
      final order = _orderService.getOrderById(orderId);
      if (order == null) {
        debugPrint('❌ Order not found: $orderId');
        return false;
      }

      // Create new taken item
      final takenItem = TakenItem(
        courierId: courierId,
        quantity: quantity,
        notes: notes,
      );

      // Add to the order's taken items list
      order.takenItems = [...order.takenItems, takenItem];

      // Update the order status to reflect that items are being taken
      if (order.status == 'pending' || order.status == 'in_progress') {
        order.status = 'in_progress';
      }

      // Check if all items have been taken to update the overall completion status
      final totalTaken = order.takenItems.fold(0, (sum, item) => sum + item.quantity);
      if (totalTaken >= order.quantity) {
        order.status = 'completed';
        order.fullyCompletedAt = DateTime.now();
      }

      // Update the order in both Hive and Supabase
      final result = await _orderService.updateOrder(order);
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
      debugPrint('❌ Error adding taken item: $e');
      return false;
    }
  }

  /// Get all taken items for an order
  List<TakenItem> getTakenItemsForOrder(String orderId) {
    try {
      final order = _orderService.getOrderById(orderId);
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
      final order = _orderService.getOrderById(orderId);
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
      final order = _orderService.getOrderById(orderId);
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
      final allOrders = _orderService.getAllOrders();
      return allOrders.where((order) => order.takenItems.isNotEmpty).toList();
    } catch (e) {
      debugPrint('❌ Error getting orders with taken items: $e');
      return [];
    }
  }

  /// Get analytics for taken items by courier
  Map<String, int> getTakenItemsByCourier() {
    try {
      final orders = getOrdersWithTakenItems();
      final Map<String, int> courierStats = {};

      for (final order in orders) {
        for (final takenItem in order.takenItems) {
          courierStats[takenItem.courierId] = 
            (courierStats[takenItem.courierId] ?? 0) + takenItem.quantity;
        }
      }

      return courierStats;
    } catch (e) {
      debugPrint('❌ Error getting taken items by courier: $e');
      return {};
    }
  }
}