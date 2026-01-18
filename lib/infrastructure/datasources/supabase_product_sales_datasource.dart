/// Supabase Product Sales Datasource
/// 
/// Handles product sales history operations

import '../../domain/entities/product_sale.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import 'supabase_client.dart';

class SupabaseProductSalesDatasource {
  final AppSupabaseClient _client = AppSupabaseClient.instance;
  
  // Expose currentUserId for repository access
  String? get currentUserId => _client.currentUserId;
  
  String get _tableName => 'product_sales';
  
  /// Create sales entry
  Future<Either<Failure, ProductSale>> createSale({
    required String productId,
    required String productName,
    required String departmentId,
    required String departmentName,
    required int quantity,
    String? orderId,
    String? soldBy,
  }) async {
    try {
      final json = {
        'product_id': productId,
        'product_name': productName,
        'department_id': departmentId,
        'department_name': departmentName,
        'quantity': quantity,
        'order_id': orderId,
        'sold_by': soldBy,
      };
      
      final response = await _client.client
          .from(_tableName)
          .insert(json)
          .select('''
            *,
            users:sold_by (
              name
            )
          ''')
          .single();
      
      // Get user name
      String? soldByName;
      if (response['users'] != null && response['users'] is Map) {
        soldByName = (response['users'] as Map)['name'] as String?;
      }
      
      return Right(_mapFromJson(response, soldByName));
    } catch (e) {
      return Left(ServerFailure('Failed to create sale: $e'));
    }
  }
  
  /// Get sales for a specific product
  Future<Either<Failure, List<ProductSale>>> getProductSales(String productId) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select('''
            *,
            users:sold_by (
              name
            )
          ''')
          .eq('product_id', productId)
          .order('sold_at', ascending: false);
      
      final sales = (response as List).map((json) {
        final soldByName = json['users'] != null && json['users'] is Map
            ? (json['users'] as Map)['name'] as String?
            : null;
        return _mapFromJson(json, soldByName);
      }).toList();
      
      return Right(sales);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch sales: $e'));
    }
  }
  
  /// Get all sales (for admin)
  Future<Either<Failure, List<ProductSale>>> getAllSales() async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select('''
            *,
            users:sold_by (
              name
            )
          ''')
          .order('sold_at', ascending: false)
          .limit(100);
      
      final sales = (response as List).map((json) {
        final soldByName = json['users'] != null && json['users'] is Map
            ? (json['users'] as Map)['name'] as String?
            : null;
        return _mapFromJson(json, soldByName);
      }).toList();
      
      return Right(sales);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch sales: $e'));
    }
  }
  
  /// Delete sales entries for a specific order
  Future<Either<Failure, void>> deleteSalesByOrderId(String orderId) async {
    try {
      await _client.client
          .from(_tableName)
          .delete()
          .eq('order_id', orderId);
      
      return Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to delete sales for order: $e'));
    }
  }
  
  ProductSale _mapFromJson(Map<String, dynamic> json, String? soldByName) {
    return ProductSale(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      departmentId: json['department_id'] as String,
      departmentName: json['department_name'] as String,
      quantity: json['quantity'] as int,
      orderId: json['order_id'] as String?,
      soldBy: json['sold_by'] as String?,
      soldByName: soldByName,
      soldAt: DateTime.parse(json['sold_at'] as String),
    );
  }
}

