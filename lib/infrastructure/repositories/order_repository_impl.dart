/// Order Repository Implementation
/// 
/// Handles order operations with Supabase and Hive cache

import 'package:flutter/foundation.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/entities/order.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../datasources/supabase_order_datasource.dart';
import '../cache/hive_order_cache.dart';

class OrderRepositoryImpl implements OrderRepository {
  final SupabaseOrderDatasource _supabaseDatasource;
  final HiveOrderCache _cache;

  OrderRepositoryImpl({
    required SupabaseOrderDatasource supabaseDatasource,
    required HiveOrderCache cache,
  })  : _supabaseDatasource = supabaseDatasource,
        _cache = cache;

  @override
  Future<Either<Failure, List<Order>>> getAllOrders() async {
    // Try cache first, then Supabase
    try {
      final cachedResult = await _cache.getAllOrders();
      return cachedResult.fold(
        (failure) async {
          // Cache failed, try Supabase
          final result = await _supabaseDatasource.getAllOrders();
          return result.fold(
            (supabaseFailure) => Left(supabaseFailure),
            (orders) async {
              await _cache.saveOrders(orders);
              return Right(orders);
            },
          );
        },
        (cachedOrders) async {
          if (cachedOrders.isNotEmpty) {
            return Right(cachedOrders);
          }
          // Cache is empty, try Supabase
          final result = await _supabaseDatasource.getAllOrders();
          return result.fold(
            (failure) => Left(failure),
            (orders) async {
              await _cache.saveOrders(orders);
              return Right(orders);
            },
          );
        },
      );
    } catch (e) {
      debugPrint('⚠️ Cache read error: $e');
      // Fallback to Supabase
      final result = await _supabaseDatasource.getAllOrders();
      return result.fold(
        (failure) => Left(failure),
        (orders) async {
          await _cache.saveOrders(orders);
          return Right(orders);
        },
      );
    }
  }

  @override
  Future<Either<Failure, Order?>> getOrderById(String orderId) async {
    final result = await _supabaseDatasource.getOrderById(orderId);
    return result;
  }

  @override
  Future<Either<Failure, List<Order>>> getOrdersByStatus(String status) async {
    return await _supabaseDatasource.getOrdersByStatus(status);
  }

  @override
  Future<Either<Failure, List<Order>>> getOrdersByDepartment(String departmentId) async {
    return await _supabaseDatasource.getOrdersByDepartment(departmentId);
  }

  @override
  Future<Either<Failure, List<Order>>> searchOrders(String query) async {
    return await _supabaseDatasource.searchOrders(query);
  }

  @override
  Future<Either<Failure, Order>> createOrder(Order order) async {
    final result = await _supabaseDatasource.createOrder(order);
    return result.fold(
      (failure) => Left(failure),
      (createdOrder) async {
        // Update cache
        await _cache.saveOrder(createdOrder);
        return Right(createdOrder);
      },
    );
  }

  @override
  Future<Either<Failure, Order>> updateOrder(Order order) async {
    final result = await _supabaseDatasource.updateOrder(order);
    return result.fold(
      (failure) => Left(failure),
      (updatedOrder) async {
        // Update cache
        await _cache.saveOrder(updatedOrder);
        return Right(updatedOrder);
      },
    );
  }

  @override
  Future<Either<Failure, Order>> approveOrder(String orderId, String approvedBy) async {
    return await _supabaseDatasource.approveOrder(orderId, approvedBy);
  }

  @override
  Future<Either<Failure, Order>> rejectOrder(String orderId, String rejectedBy) async {
    return await _supabaseDatasource.rejectOrder(orderId, rejectedBy);
  }

  @override
  Future<Either<Failure, Order>> completeOrder(String orderId) async {
    // Get current order first
    final orderResult = await getOrderById(orderId);
    return await orderResult.fold(
      (failure) => Left(failure),
      (order) async {
        if (order == null) {
          return Left<Failure, Order>(ServerFailure('Order not found'));
        }
        
        // Update status to completed
        final updatedOrder = order.copyWith(
          status: 'completed',
          updatedAt: DateTime.now(),
        );
        
        return await updateOrder(updatedOrder);
      },
    );
  }

  @override
  Future<Either<Failure, void>> deleteOrder(String orderId) async {
    final result = await _supabaseDatasource.deleteOrder(orderId);
    return result.fold(
      (failure) => Left(failure),
      (_) async {
        // Remove from cache
        await _cache.deleteOrder(orderId);
        return Right(null);
      },
    );
  }

  @override
  Stream<Either<Failure, List<Order>>> watchOrders() {
    // WHY: Fixed stream error handling - properly wraps errors in Either
    return _supabaseDatasource.watchOrders().map((orders) {
      // Update cache when data changes (async but don't await - fire and forget)
      _cache.saveOrders(orders).then((_) {
        // Cache updated successfully
      }).catchError((e) {
        // Log cache error but don't fail the stream
        debugPrint('⚠️ Cache update error: $e');
      });
      return Right<Failure, List<Order>>(orders);
    }).handleError((error, stackTrace) {
      // Return error as Left
      return Left<Failure, List<Order>>(ServerFailure('Stream error: $error'));
    });
  }

  @override
  Future<Either<Failure, List<Order>>> getOrdersThisMonth() async {
    return await _supabaseDatasource.getOrdersThisMonth();
  }

  @override
  Future<Either<Failure, int>> getProductionCountForMonth(DateTime month) async {
    return await _supabaseDatasource.getProductionCountForMonth(month);
  }
}

