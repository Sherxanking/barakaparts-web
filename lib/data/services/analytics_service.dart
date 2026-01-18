/// Analytics Service
/// 
/// WHY: Provides analytics and statistics for orders, parts, and products
/// Supports: Monthly production count, parts usage history, department-based reporting

import 'package:flutter/foundation.dart' show debugPrint;
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
}


