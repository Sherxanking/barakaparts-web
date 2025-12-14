/// Order repository interface - Domain layer

import '../entities/order.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

abstract class OrderRepository {
  /// Get all orders
  Future<Either<Failure, List<Order>>> getAllOrders();
  
  /// Get order by ID
  Future<Either<Failure, Order?>> getOrderById(String orderId);
  
  /// Get orders by status
  Future<Either<Failure, List<Order>>> getOrdersByStatus(String status);
  
  /// Get orders by department
  Future<Either<Failure, List<Order>>> getOrdersByDepartment(String departmentId);
  
  /// Search orders
  Future<Either<Failure, List<Order>>> searchOrders(String query);
  
  /// Create a new order
  Future<Either<Failure, Order>> createOrder(Order order);
  
  /// Update an existing order
  Future<Either<Failure, Order>> updateOrder(Order order);
  
  /// Approve an order
  Future<Either<Failure, Order>> approveOrder(String orderId, String approvedBy);
  
  /// Reject an order
  Future<Either<Failure, Order>> rejectOrder(String orderId, String rejectedBy);
  
  /// Complete an order (reduce stock)
  Future<Either<Failure, Order>> completeOrder(String orderId);
  
  /// Delete an order
  Future<Either<Failure, void>> deleteOrder(String orderId);
  
  /// Stream orders for real-time updates
  Stream<Either<Failure, List<Order>>> watchOrders();
  
  /// Get orders created this month
  Future<Either<Failure, List<Order>>> getOrdersThisMonth();
  
  /// Get production count for a month
  Future<Either<Failure, int>> getProductionCountForMonth(DateTime month);
}

