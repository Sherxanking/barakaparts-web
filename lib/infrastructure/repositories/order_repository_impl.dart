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
import '../../domain/entities/part.dart';
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
        
        // Check if already completed
        if (order.status == 'completed') {
          return Left<Failure, Order>(ServerFailure('Order is already completed'));
        }
        
        // Get product to find parts required
        final productResult = await _productRepository.getProductById(order.productId);
        return await productResult.fold(
          (failure) => Left<Failure, Order>(failure),
          (product) async {
            if (product == null) {
              return Left<Failure, Order>(ServerFailure('Product not found'));
            }
            
            // Prefer order-specific parts if provided (pending edits)
            final partsRequired = (order.partsRequired != null && order.partsRequired!.isNotEmpty)
                ? order.partsRequired!
                : product.partsRequired;

            // OPTIMIZATION: Get all parts at once instead of one by one
            if (partsRequired.isNotEmpty) {
              // Get all parts in one request
              final allPartsResult = await _partRepository.getAllParts();
              Failure? allPartsFailure;
              final allParts = await allPartsResult.fold(
                (failure) async {
                  allPartsFailure = failure;
                  return <String, Part>{};
                },
                (parts) async => {for (var part in parts) part.id: part},
              );
              if (allPartsFailure != null) {
                return Left<Failure, Order>(allPartsFailure!);
              }
              
              // Validate all parts first
              for (var entry in partsRequired.entries) {
                final partId = entry.key;
                final qtyPerProduct = entry.value;
                final totalQty = qtyPerProduct * order.quantity;
                
                final part = allParts[partId];
                if (part == null) {
                  return Left<Failure, Order>(
                    ServerFailure('Part not found: $partId'),
                  );
                }
                
                // Check if sufficient quantity
                if (part.quantity < totalQty) {
                  return Left<Failure, Order>(
                    ServerFailure(
                      'Insufficient quantity for part ${part.name}. Required: $totalQty, Available: ${part.quantity}',
                    ),
                  );
                }
              }
              
              // Update all parts in parallel
              final updateFutures = partsRequired.entries.map((entry) async {
                final partId = entry.key;
                final qtyPerProduct = entry.value;
                final totalQty = qtyPerProduct * order.quantity;
                
                final part = allParts[partId]!; // Already validated above
                
                // Decrease quantity
                final updatedPart = part.copyWith(
                  quantity: part.quantity - totalQty,
                  updatedAt: DateTime.now(),
                );
                
                final updateResult = await _partRepository.updatePart(
                  updatedPart,
                  // Use existing action type to avoid backend constraints; notes carry context.
                  historyAction: 'update',
                  historyNotes:
                      'Order: ${order.productName} x${order.quantity} (ID: ${order.id})',
                );
                return updateResult.fold(
                  (failure) => Left<Failure, void>(failure),
                  (_) {
                    debugPrint('✅ Decreased $totalQty units of part ${part.name} (from ${part.quantity} to ${updatedPart.quantity})');
                    return Right<Failure, void>(null);
                  },
                );
              }).toList();
              
              // Wait for all updates to complete
              final updateResults = await Future.wait(updateFutures);
              
              // Check if any update failed
              for (var result in updateResults) {
                final error = await result.fold(
                  (failure) => failure,
                  (_) => null,
                );
                if (error != null) {
                  return Left<Failure, Order>(error);
                }
              }
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
        // OPTIMIZATION: Background'da ishlaydi - user kutmaydi
        if (order.status == 'completed') {
          final partsRequired = order.partsRequired;
          
          if (partsRequired != null && partsRequired.isNotEmpty) {
            // OPTIMIZATION: Faqat kerakli part'larni olish (getAllParts o'rniga)
            // Background'da restore qilish - user kutmaydi
            Future.microtask(() async {
              try {
                // Get only required parts in parallel
                final partFutures = partsRequired.keys.map((partId) => 
                  _partRepository.getPartById(partId)
                ).toList();
                
                final partResults = await Future.wait(partFutures);
                
                // Update all parts in parallel
                final updateFutures = <Future<void>>[];
                for (int i = 0; i < partResults.length; i++) {
                  final partResult = partResults[i];
                  final entry = partsRequired.entries.elementAt(i);
                  final partId = entry.key;
                  final qtyPerProduct = entry.value;
                  final totalQty = qtyPerProduct * order.quantity;
                  
                  partResult.fold(
                    (failure) {
                      debugPrint('⚠️ Failed to get part $partId: ${failure.message}');
                    },
                    (part) {
                      if (part != null) {
                        final updatedPart = part.copyWith(
                          quantity: part.quantity + totalQty,
                          updatedAt: DateTime.now(),
                        );
                        
                        updateFutures.add(
                          _partRepository.updatePart(updatedPart).then((result) {
                            result.fold(
                              (failure) => debugPrint('⚠️ Failed to restore part $partId: ${failure.message}'),
                              (_) => debugPrint('✅ Restored $totalQty units of part ${part.name}'),
                            );
                          }),
                        );
                      }
                    },
                  );
                }
                
                await Future.wait(updateFutures);
              } catch (e) {
                debugPrint('⚠️ Error restoring parts in background: $e');
              }
            });
          } else {
            // Fallback: Product'dan olish (background'da)
            Future.microtask(() async {
              try {
                final productResult = await _productRepository.getProductById(order.productId);
                await productResult.fold(
                  (failure) async {
                    debugPrint('⚠️ Failed to get product: ${failure.message}');
                  },
                  (product) async {
                    if (product != null && product.partsRequired.isNotEmpty) {
                      // Get only required parts in parallel
                      final partFutures = product.partsRequired.keys.map((partId) => 
                        _partRepository.getPartById(partId)
                      ).toList();
                      
                      final partResults = await Future.wait(partFutures);
                      
                      // Update all parts in parallel
                      final updateFutures = <Future<void>>[];
                      for (int i = 0; i < partResults.length; i++) {
                        final partResult = partResults[i];
                        final entry = product.partsRequired.entries.elementAt(i);
                        final partId = entry.key;
                        final qtyPerProduct = entry.value;
                        final totalQty = qtyPerProduct * order.quantity;
                        
                        partResult.fold(
                          (failure) {
                            debugPrint('⚠️ Failed to get part $partId: ${failure.message}');
                          },
                          (part) {
                            if (part != null) {
                              final updatedPart = part.copyWith(
                                quantity: part.quantity + totalQty,
                                updatedAt: DateTime.now(),
                              );
                              
                              updateFutures.add(
                                _partRepository.updatePart(updatedPart).then((result) {
                                  result.fold(
                                    (failure) => debugPrint('⚠️ Failed to restore part $partId: ${failure.message}'),
                                    (_) => debugPrint('✅ Restored $totalQty units of part ${part.name}'),
                                  );
                                }),
                              );
                            }
                          },
                        );
                      }
                      
                      await Future.wait(updateFutures);
                    }
                  },
                );
              } catch (e) {
                debugPrint('⚠️ Error restoring parts in background: $e');
              }
            });
          }
        }
        
        // OPTIMIZATION: CASCADE DELETE bor bo'lsa, bu ortiqcha
        // Lekin xavfsizlik uchun qoldiramiz (agar CASCADE yo'q bo'lsa)
        // Background'da ishlaydi - user kutmaydi
        Future.microtask(() async {
          try {
            final deleteSalesResult = await _salesDatasource.deleteSalesByOrderId(orderId);
            deleteSalesResult.fold(
              (failure) {
                debugPrint('⚠️ Failed to delete sales for order $orderId: ${failure.message}');
              },
              (_) {
                debugPrint('✅ Deleted sales entries for order $orderId');
              },
            );
          } catch (e) {
            debugPrint('⚠️ Error deleting sales in background: $e');
          }
        });
        
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

  // Yangi qo'shilayotgan metodlar

  @override
  Future<Either<Failure, bool>> softDeleteOrder(String orderId, {String? reason}) async {
    try {
      final result = await _supabaseDatasource.softDeleteOrder(orderId, reason: reason);
      return result.fold(
        (failure) => Left(failure),
        (success) async {
          // Cache'dan ham o'chirish
          if (success) {
            await _cache.deleteOrder(orderId);
          }
          return Right(success);
        },
      );
    } catch (e) {
      return Left(ServerFailure('Soft delete failed: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> restoreOrder(String orderId) async {
    try {
      final result = await _supabaseDatasource.restoreOrder(orderId);
      return result.fold(
        (failure) => Left(failure),
        (success) async {
          // Agar muvaffaqiyatli bo'lsa, cache'ga qayta qo'shish
          if (success) {
            final orderResult = await getOrderById(orderId);
            await orderResult.fold(
              (failure) async {},
              (order) async {
                if (order != null) {
                  await _cache.saveOrder(order);
                }
              },
            );
          }
          return Right(success);
        },
      );
    } catch (e) {
      return Left(ServerFailure('Restore failed: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> permanentlyDeleteOrder(String orderId) async {
    try {
      final result = await _supabaseDatasource.permanentlyDeleteOrder(orderId);
      return result.fold(
        (failure) => Left(failure),
        (success) async {
          // Cache'dan ham o'chirish
          if (success) {
            await _cache.deleteOrder(orderId);
          }
          return Right(success);
        },
      );
    } catch (e) {
      return Left(ServerFailure('Permanent delete failed: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Order>>> getDeletedOrders() async {
    try {
      return await _supabaseDatasource.getDeletedOrders();
    } catch (e) {
      return Left(ServerFailure('Failed to get deleted orders: $e'));
    }
  }
}

