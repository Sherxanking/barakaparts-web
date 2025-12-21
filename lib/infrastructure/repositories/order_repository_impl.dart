/// Order Repository Implementation
/// 
/// Handles order operations with Supabase and Hive cache

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/department_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/part_repository.dart';
import '../../domain/entities/order.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../datasources/supabase_order_datasource.dart';
import '../datasources/supabase_product_sales_datasource.dart';
import '../cache/hive_order_cache.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/order_model.dart' as model;

class OrderRepositoryImpl implements OrderRepository {
  final SupabaseOrderDatasource _supabaseDatasource;
  final HiveOrderCache _cache;
  final SupabaseProductSalesDatasource _salesDatasource = SupabaseProductSalesDatasource();
  final DepartmentRepository _departmentRepository = ServiceLocator.instance.departmentRepository;
  final ProductRepository _productRepository = ServiceLocator.instance.productRepository;
  final PartRepository _partRepository = ServiceLocator.instance.partRepository;
  
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
        
        final updateResult = await updateOrder(updatedOrder);
        
        // Create sales history entry
        updateResult.fold(
          (failure) {},
          (completedOrder) async {
            // Get department name
            final deptResult = await _departmentRepository.getDepartmentById(completedOrder.departmentId);
            deptResult.fold(
              (failure) {
                debugPrint('⚠️ Failed to get department: ${failure.message}');
              },
              (department) async {
                if (department != null) {
                  // Get current user ID
                  final currentUserId = _salesDatasource.currentUserId;
                  
                  // Create sales entry
                  final salesResult = await _salesDatasource.createSale(
                    productId: completedOrder.productId,
                    productName: completedOrder.productName,
                    departmentId: completedOrder.departmentId,
                    departmentName: department.name,
                    quantity: completedOrder.quantity,
                    orderId: completedOrder.id,
                    soldBy: currentUserId,
                  );
                  
                  salesResult.fold(
                    (failure) => debugPrint('⚠️ Failed to create sales history: ${failure.message}'),
                    (_) => debugPrint('✅ Sales history created'),
                  );
                }
              },
            );
          },
        );
        
        return updateResult;
      },
    );
  }

  @override
  Future<Either<Failure, void>> deleteOrder(String orderId) async {
    // Get order first to check if it's completed
    final orderResult = await getOrderById(orderId);
    return await orderResult.fold(
      (failure) => Left(failure),
      (order) async {
        if (order == null) {
          return Left<Failure, void>(ServerFailure('Order not found'));
        }
        
        // If order is completed, restore parts quantities
        if (order.status == 'completed') {
          // Get product to find parts
          final productResult = await _productRepository.getProductById(order.productId);
          await productResult.fold(
            (failure) async {
              debugPrint('⚠️ Failed to get product: ${failure.message}');
            },
            (product) async {
              if (product != null && product.partsRequired.isNotEmpty) {
                // Restore parts quantities
                for (var entry in product.partsRequired.entries) {
                  final partId = entry.key;
                  final qtyPerProduct = entry.value;
                  final totalQty = qtyPerProduct * order.quantity;
                  
                  // Get current part
                  final partResult = await _partRepository.getPartById(partId);
                  partResult.fold(
                    (failure) {
                      debugPrint('⚠️ Failed to get part $partId: ${failure.message}');
                    },
                    (part) async {
                      if (part != null) {
                        // Increase quantity
                        final updatedPart = part.copyWith(
                          quantity: part.quantity + totalQty,
                          updatedAt: DateTime.now(),
                        );
                        
                        final updateResult = await _partRepository.updatePart(updatedPart);
                        updateResult.fold(
                          (failure) {
                            debugPrint('⚠️ Failed to restore part $partId: ${failure.message}');
                          },
                          (_) {
                            debugPrint('✅ Restored $totalQty units of part ${part.name}');
                          },
                        );
                      }
                    },
                  );
                }
              }
            },
          );
        }
        
        // Delete order
        final deleteResult = await _supabaseDatasource.deleteOrder(orderId);
        return deleteResult.fold(
          (failure) => Left(failure),
          (_) async {
            // Remove from cache
            await _cache.deleteOrder(orderId);
            return Right(null);
          },
        );
      },
    );
  }

  @override
  Stream<Either<Failure, List<Order>>> watchOrders() {
    // WHY: Fixed stream error handling - properly wraps errors in Either
    return _supabaseDatasource.watchOrders().map((orders) {
      debugPrint('🔄 watchOrders: Received ${orders.length} orders from Supabase');
      
      // Update cache when data changes (async but don't await - fire and forget)
      _cache.saveOrders(orders).then((_) {
        debugPrint('✅ Orders cache updated');
      }).catchError((e) {
        // Log cache error but don't fail the stream
        debugPrint('⚠️ Cache update error: $e');
      });
      
      // FIX: Also update ordersBox for UI sync
      _updateOrdersBox(orders).then((_) {
        debugPrint('✅ OrdersBox updated from stream');
      }).catchError((e) {
        debugPrint('⚠️ OrdersBox update error: $e');
      });
      
      return Right<Failure, List<Order>>(orders);
    }).handleError((error, stackTrace) {
      debugPrint('❌ Orders stream error: $error');
      debugPrint('Stack trace: $stackTrace');
      // Return error as Left
      return Left<Failure, List<Order>>(ServerFailure('Stream error: $error'));
    });
  }
  
  /// Update ordersBox with domain orders
  /// FIX: ValueListenableBuilder yangilanishi uchun to'g'ri yozish
  Future<void> _updateOrdersBox(List<Order> domainOrders) async {
    try {
      if (!Hive.isBoxOpen('ordersBox')) {
        await Hive.openBox<model.Order>('ordersBox');
      }
      final box = Hive.box<model.Order>('ordersBox');
      
      debugPrint('🔄 Updating ordersBox with ${domainOrders.length} orders');
      
      // FIX: Clear va add o'rniga, mavjud elementlarni yangilash yoki qo'shish
      final existingKeys = box.keys.toList();
      final newOrderIds = domainOrders.map((o) => o.id).toSet();
      
      // Eski elementlarni o'chirish (mavjud bo'lmaganlar)
      for (var key in existingKeys) {
        final order = box.get(key);
        if (order != null && !newOrderIds.contains(order.id)) {
          await box.delete(key);
        }
      }
      
      // Yangi elementlarni qo'shish yoki yangilash
      for (var domainOrder in domainOrders) {
        final orderModel = model.Order(
          id: domainOrder.id,
          departmentId: domainOrder.departmentId,
          productName: domainOrder.productName,
          quantity: domainOrder.quantity,
          status: domainOrder.status,
          createdAt: domainOrder.createdAt,
        );
        
        // Mavjud bo'lsa, yangilash; yo'q bo'lsa, qo'shish
        final existingIndex = box.values.toList().indexWhere((o) => o.id == domainOrder.id);
        if (existingIndex >= 0) {
          await box.putAt(existingIndex, orderModel);
        } else {
          await box.add(orderModel);
        }
      }
      
      debugPrint('✅ OrdersBox updated with ${domainOrders.length} orders');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error updating ordersBox: $e');
      debugPrint('Stack trace: $stackTrace');
    }
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

