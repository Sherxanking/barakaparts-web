/// Analytics Service
/// 
/// WHY: Provides analytics and statistics for orders, parts, and products
/// Supports: Monthly production count, parts usage history, department-based reporting

import 'package:flutter/foundation.dart' show debugPrint;
import '../../domain/entities/order.dart';
import '../../domain/entities/part.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/part_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/department_repository.dart';
import '../../core/di/service_locator.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

class AnalyticsService {
  final OrderRepository _orderRepository = ServiceLocator.instance.orderRepository;
  final PartRepository _partRepository = ServiceLocator.instance.partRepository;
  final ProductRepository _productRepository = ServiceLocator.instance.productRepository;
  final DepartmentRepository _departmentRepository = ServiceLocator.instance.departmentRepository;
  
  /// Helper: Get completed orders within a given month
  Future<Either<Failure, List<Order>>> _getCompletedOrdersForMonth(DateTime month) async {
    final ordersResult = await _orderRepository.getAllOrders();
    return ordersResult.fold(
      (failure) => Left(failure),
      (orders) {
        final startOfMonth = DateTime(month.year, month.month, 1);
        final startOfNextMonth = DateTime(month.year, month.month + 1, 1);
        
        final filtered = orders.where((order) {
          if (order.status != 'completed') return false;
          final timestamp = order.updatedAt ?? order.createdAt;
          return !timestamp.isBefore(startOfMonth) && timestamp.isBefore(startOfNextMonth);
        }).toList();
        
        return Right(filtered);
      },
    );
  }

  /// Get total production count for this month
  Future<Either<Failure, int>> getThisMonthProductionCount() async {
    final now = DateTime.now();
    return await _orderRepository.getProductionCountForMonth(now);
  }

  /// Get production count for a specific month
  Future<Either<Failure, int>> getProductionCountForMonth(DateTime month) async {
    return await _orderRepository.getProductionCountForMonth(month);
  }

  /// Get production count for last N months
  Future<Either<Failure, Map<String, int>>> getProductionCountForLastMonths(int months) async {
    final result = <String, int>{};
    
    for (int i = months - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i * 30));
      final month = DateTime(date.year, date.month, 1);
      
      final countResult = await _orderRepository.getProductionCountForMonth(month);
      countResult.fold(
        (failure) {
          result['${month.year}-${month.month.toString().padLeft(2, '0')}'] = 0;
        },
        (count) {
          result['${month.year}-${month.month.toString().padLeft(2, '0')}'] = count;
        },
      );
    }
    
    return Right(result);
  }

  /// Get orders count by status
  Future<Either<Failure, Map<String, int>>> getOrdersCountByStatus() async {
    final ordersResult = await _orderRepository.getAllOrders();
    
    return ordersResult.fold(
      (failure) => Left(failure),
      (orders) {
        final counts = <String, int>{
          'pending': 0,
          'approved': 0,
          'completed': 0,
          'rejected': 0,
        };
        
        for (final order in orders) {
          counts[order.status] = (counts[order.status] ?? 0) + 1;
        }
        
        return Right(counts);
      },
    );
  }

  /// Get orders count by department
  Future<Either<Failure, Map<String, int>>> getOrdersCountByDepartment() async {
    final ordersResult = await _orderRepository.getAllOrders();
    final departmentsResult = await _departmentRepository.getAllDepartments();
    
    return ordersResult.fold(
      (failure) => Left(failure),
      (orders) {
        return departmentsResult.fold(
          (failure) => Left(failure),
          (departments) {
            final counts = <String, int>{};
            
            // Initialize all departments with 0
            for (final dept in departments) {
              counts[dept.id] = 0;
            }
            
            // Count orders by department
            for (final order in orders) {
              if (order.departmentId != null) {
                counts[order.departmentId!] = (counts[order.departmentId!] ?? 0) + 1;
              }
            }
            
            return Right(counts);
          },
        );
      },
    );
  }
  
  /// Get completed orders quantity by department name for a month
  Future<Either<Failure, Map<String, int>>> getOrdersQuantityByDepartmentForMonth(DateTime month) async {
    final completedOrdersResult = await _getCompletedOrdersForMonth(month);
    final departmentsResult = await _departmentRepository.getAllDepartments();
    
    return completedOrdersResult.fold(
      (failure) => Left(failure),
      (orders) {
        return departmentsResult.fold(
          (failure) => Left(failure),
          (departments) {
            final departmentNames = {
              for (final dept in departments) dept.id: dept.name,
            };
            final counts = <String, int>{};
            
            for (final order in orders) {
              final deptName = departmentNames[order.departmentId] ?? 'Unknown';
              counts[deptName] = (counts[deptName] ?? 0) + order.quantity;
            }
            
            return Right(counts);
          },
        );
      },
    );
  }

  /// Get low stock parts count
  Future<Either<Failure, int>> getLowStockPartsCount() async {
    final partsResult = await _partRepository.getAllParts();
    
    return partsResult.fold(
      (failure) => Left(failure),
      (parts) {
        final lowStockCount = parts.where((p) => p.quantity < p.minQuantity).length;
        return Right(lowStockCount);
      },
    );
  }
  
  /// Get low stock parts list
  Future<Either<Failure, List<Part>>> getLowStockPartsList() async {
    return await _partRepository.getLowStockParts();
  }

  /// Get total parts count
  Future<Either<Failure, int>> getTotalPartsCount() async {
    final partsResult = await _partRepository.getAllParts();
    
    return partsResult.fold(
      (failure) => Left(failure),
      (parts) => Right(parts.length),
    );
  }

  /// Get total products count
  Future<Either<Failure, int>> getTotalProductsCount() async {
    final productsResult = await _productRepository.getAllProducts();
    
    return productsResult.fold(
      (failure) => Left(failure),
      (products) => Right(products.length),
    );
  }

  /// Get total departments count
  Future<Either<Failure, int>> getTotalDepartmentsCount() async {
    final departmentsResult = await _departmentRepository.getAllDepartments();
    
    return departmentsResult.fold(
      (failure) => Left(failure),
      (departments) => Right(departments.length),
    );
  }

  /// Get parts usage history (top N most used parts)
  Future<Either<Failure, Map<String, int>>> getPartsUsageHistory({int limit = 10}) async {
    // This would require tracking part usage in orders
    // For now, return empty map
    // TODO: Implement when order completion tracks part usage
    return Right({});
  }

  /// Get production count by product for this month
  Future<Either<Failure, Map<String, int>>> getProductionCountByProductThisMonth() async {
    final ordersResult = await _orderRepository.getAllOrders();
    final productsResult = await _productRepository.getAllProducts();
    
    return ordersResult.fold(
      (failure) => Left(failure),
      (orders) {
        return productsResult.fold(
          (failure) => Left(failure),
          (products) {
            final now = DateTime.now();
            final thisMonthStart = DateTime(now.year, now.month, 1);
            final nextMonthStart = DateTime(now.year, now.month + 1, 1);
            
            final counts = <String, int>{};
            
            // Initialize all products with 0
            for (final product in products) {
              counts[product.id] = 0;
            }
            
            // Count completed orders by product for this month
            for (final order in orders) {
              if (order.status == 'completed' &&
                  order.updatedAt != null &&
                  order.updatedAt!.isAfter(thisMonthStart) &&
                  order.updatedAt!.isBefore(nextMonthStart)) {
                counts[order.productId] = (counts[order.productId] ?? 0) + order.quantity;
              }
            }
            
            // Remove products with 0 count
            counts.removeWhere((key, value) => value == 0);
            
            return Right(counts);
          },
        );
      },
    );
  }

  /// Get production count by product name for this month (with product names)
  Future<Either<Failure, Map<String, int>>> getProductionCountByProductNameThisMonth() async {
    final result = await getProductionCountByProductThisMonth();
    
    return result.fold(
      (failure) => Left(failure),
      (productCounts) async {
        final productsResult = await _productRepository.getAllProducts();
        
        return productsResult.fold(
          (failure) => Left(failure),
          (products) {
            final countsByName = <String, int>{};
            
            for (final entry in productCounts.entries) {
              try {
                final product = products.firstWhere(
                  (p) => p.id == entry.key,
                );
                countsByName[product.name] = entry.value;
              } catch (e) {
                // Product topilmadi, skip qilish
                debugPrint('⚠️ Product not found: ${entry.key}');
              }
            }
            
            return Right(countsByName);
          },
        );
      },
    );
  }
  
  /// Get parts usage map (part_id -> total used) for a month
  Future<Either<Failure, Map<String, int>>> getPartsUsageByIdForMonth(DateTime month) async {
    final completedOrdersResult = await _getCompletedOrdersForMonth(month);
    
    return completedOrdersResult.fold(
      (failure) => Left(failure),
      (orders) {
        final usage = <String, int>{};
        for (final order in orders) {
          final partsRequired = order.partsRequired;
          if (partsRequired == null || partsRequired.isEmpty) continue;
          
          for (final entry in partsRequired.entries) {
            final partId = entry.key;
            final perProduct = entry.value;
            final totalUsed = perProduct * order.quantity;
            usage[partId] = (usage[partId] ?? 0) + totalUsed;
          }
        }
        return Right(usage);
      },
    );
  }
  
  /// Get parts usage by part name for a month (sorted, optional limit)
  Future<Either<Failure, Map<String, int>>> getPartsUsageByNameForMonth(
    DateTime month, {
    int? limit,
  }) async {
    final usageResult = await getPartsUsageByIdForMonth(month);
    final partsResult = await _partRepository.getAllParts();
    
    return usageResult.fold(
      (failure) => Left(failure),
      (usageById) {
        return partsResult.fold(
          (failure) => Left(failure),
          (parts) {
            final partNames = {
              for (final part in parts) part.id: part.name,
            };
            
            final entries = usageById.entries
                .map((entry) => MapEntry(partNames[entry.key] ?? entry.key, entry.value))
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            
            final limited = (limit != null && entries.length > limit)
                ? entries.take(limit).toList()
                : entries;
            
            final result = <String, int>{};
            for (final entry in limited) {
              result[entry.key] = entry.value;
            }
            return Right(result);
          },
        );
      },
    );
  }
  
  /// Get product production growth (weekly/monthly)
  Future<Either<Failure, Map<String, int>>> getProductGrowth(String productId, {int months = 6}) async {
    final ordersResult = await _orderRepository.getAllOrders();
    
    return ordersResult.fold(
      (failure) => Left(failure),
      (orders) {
        final result = <String, int>{};
        final now = DateTime.now();
        
        for (int i = months - 1; i >= 0; i--) {
          final date = DateTime(now.year, now.month - i, 1);
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          
          final count = orders.where((order) {
            if (order.productId != productId || order.status != 'completed') return false;
            final timestamp = order.updatedAt ?? order.createdAt;
            return timestamp.year == date.year && timestamp.month == date.month;
          }).fold(0, (sum, order) => sum + order.quantity);
          
          result[monthKey] = count;
        }
        
        return Right(result);
      },
    );
  }

  /// Get progress stats for a specific product (Plan vs Actual, Status Distribution)
  Future<Either<Failure, Map<String, dynamic>>> getProductProgress(String productId) async {
    final ordersResult = await _orderRepository.getAllOrders();
    
    return ordersResult.fold(
      (failure) => Left(failure),
      (orders) {
        final productOrders = orders.where((o) => o.productId == productId).toList();
        
        int totalPlan = 0;
        int inProduction = 0; // Hali bitmagan, jarayondagi qismi
        int ready = 0;       // Bitgan lekin hali olib ketilmagan (Tayyor)
        int taken = 0;       // Olib ketilgan (Completed + FullyCompletedAt)
        
        for (final order in productOrders) {
          totalPlan += order.quantity;
          
          if (order.status == 'completed') {
            if (order.fullyCompletedAt != null) {
              taken += order.quantity;
            } else {
              ready += order.quantity;
            }
          } else if (order.status == 'in_progress' || order.status == 'pending') {
            // Jarayondagi buyurtmaning bitgan qismi (Tayyor)
            ready += order.completedQuantity;
            // Haqiqatda jarayonda turgan qismi
            inProduction += (order.quantity - order.completedQuantity);
          }
        }
        
        return Right({
          'totalPlan': totalPlan,
          'inProgress': inProduction,
          'ready': ready,
          'taken': taken,
          'actual': ready + taken,
          'percent': totalPlan > 0 ? ((ready + taken) / totalPlan * 100).round() : 0,
        });
      },
    );
  }

  /// Get Worker KPI (Production count, avg time)
  Future<Either<Failure, List<Map<String, dynamic>>>> getWorkerKPIs() async {
    final ordersResult = await _orderRepository.getAllOrders();
    final workersResult = await ServiceLocator.instance.userRepository.getAllUsers();
    
    return ordersResult.fold(
      (failure) => Left(failure),
      (orders) {
        return workersResult.fold(
          (failure) => Left(failure),
          (users) {
            final workers = users.where((u) => u.role == 'worker').toList();
            final stats = <Map<String, dynamic>>[];
            
            for (final worker in workers) {
              final workerOrders = orders.where((o) => o.workerId == worker.id || o.completedBy == worker.id).toList();
              final completedOrders = workerOrders.where((o) => o.status == 'completed').toList();
              
              int totalQuantity = completedOrders.fold(0, (sum, o) => sum + o.quantity);
              int inProgressCount = workerOrders.where((o) => o.status == 'in_progress').length;
              
              // Calculate avg completion time
              double totalHours = 0;
              int ordersWithTime = 0;
              for (final o in completedOrders) {
                if (o.durationHours != null) {
                  totalHours += o.durationHours!;
                  ordersWithTime++;
                }
              }
              
              stats.add({
                'workerId': worker.id,
                'workerName': worker.name,
                'role': worker.role,
                'position': worker.position,
                'completedQuantity': totalQuantity,
                'inProgressOrders': inProgressCount,
                'avgHoursPerOrder': ordersWithTime > 0 ? (totalHours / ordersWithTime) : 0.0,
              });
            }
            
            // Sort by completed quantity descending
            stats.sort((a, b) => (b['completedQuantity'] as int).compareTo(a['completedQuantity'] as int));
            
            return Right(stats);
          },
        );
      },
    );
  }

  /// Get total parts used for a month
  Future<Either<Failure, int>> getTotalPartsUsedForMonth(DateTime month) async {
    final usageResult = await getPartsUsageByIdForMonth(month);
    return usageResult.fold(
      (failure) => Left(failure),
      (usage) => Right(usage.values.fold(0, (sum, value) => sum + value)),
    );
  }
}


