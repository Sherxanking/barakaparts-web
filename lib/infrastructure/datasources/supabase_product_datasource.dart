/// Supabase Product Datasource

import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import 'supabase_client.dart';

class SupabaseProductDatasource {
  final AppSupabaseClient _client = AppSupabaseClient.instance;
  
  String get _tableName => 'products';
  
  Future<Either<Failure, List<Product>>> getAllProducts() async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);
      
      final products = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(products);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch products: $e'));
    }
  }
  
  Future<Either<Failure, Product?>> getProductById(String productId) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .eq('id', productId)
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      if (e.toString().contains('PGRST116')) {
        return Right(null);
      }
      return Left(ServerFailure('Failed to fetch product: $e'));
    }
  }
  
  Future<Either<Failure, List<Product>>> getProductsByDepartment(String departmentId) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .eq('department_id', departmentId)
          .order('name');
      
      final products = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(products);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch products by department: $e'));
    }
  }
  
  Future<Either<Failure, List<Product>>> searchProducts(String query) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .ilike('name', '%$query%')
          .order('name');
      
      final products = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(products);
    } catch (e) {
      return Left(ServerFailure('Failed to search products: $e'));
    }
  }
  
  Future<Either<Failure, Product>> createProduct(Product product) async {
    try {
      debugPrint('🔄 Creating product in Supabase:');
      debugPrint('   ID: ${product.id}');
      debugPrint('   Name: ${product.name}');
      debugPrint('   Department ID: ${product.departmentId}');
      debugPrint('   Parts Required: ${product.partsRequired}');
      debugPrint('   Created by: ${product.createdBy}');
      
      final json = _mapToJson(product);
      debugPrint('   JSON payload: $json');
      
      // Check user authentication
      final currentUserId = _client.currentUserId;
      if (currentUserId == null) {
        debugPrint('❌ No authenticated user');
        return Left(AuthFailure('You must be logged in to create products'));
      }
      debugPrint('   Current user ID: $currentUserId');
      
      final response = await _client.client
          .from(_tableName)
          .insert(json)
          .select()
          .single();
      
      debugPrint('✅ Product created successfully in Supabase');
      debugPrint('   Response ID: ${response['id']}');
      return Right(_mapFromJson(response));
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to create product in Supabase: $e');
      debugPrint('   Stack trace: $stackTrace');
      final errorStr = e.toString().toLowerCase();
      
      // Provide specific error messages
      if (errorStr.contains('null value') || errorStr.contains('not null')) {
        debugPrint('❌ Missing required field');
        return Left(ValidationFailure('Missing required field. Please check all inputs.'));
      } else if (errorStr.contains('permission') || errorStr.contains('policy')) {
        debugPrint('❌ Permission denied');
        return Left(PermissionFailure('You do not have permission to create products. Required role: manager or boss.'));
      } else if (errorStr.contains('foreign key') || errorStr.contains('department')) {
        debugPrint('❌ Foreign key constraint - department not found');
        return Left(ValidationFailure('Department does not exist. Please refresh departments and try again.'));
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        debugPrint('❌ Network error');
        return Left(ServerFailure('Network error. Please check your internet connection.'));
      } else if (errorStr.contains('duplicate key') || 
                 errorStr.contains('unique constraint') || 
                 errorStr.contains('idx_products_name_unique')) {
        debugPrint('❌ Duplicate product name');
        return Left(ValidationFailure('A product with this name already exists. Please use a different name.'));
      } else if (errorStr.contains('invalid input syntax') || errorStr.contains('uuid')) {
        debugPrint('❌ Invalid UUID format');
        return Left(ValidationFailure('Invalid data format. Please check your inputs.'));
      }
      
      debugPrint('❌ Unknown error type');
      return Left(ServerFailure('Failed to create product: $e'));
    }
  }
  
  Future<Either<Failure, Product>> updateProduct(Product product) async {
    try {
      final json = _mapToJson(product);
      json['updated_at'] = DateTime.now().toIso8601String();
      json['updated_by'] = _client.currentUserId;
      
      final response = await _client.client
          .from(_tableName)
          .update(json)
          .eq('id', product.id)
          .select()
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      return Left(ServerFailure('Failed to update product: $e'));
    }
  }
  
  Future<Either<Failure, void>> deleteProduct(String productId) async {
    try {
      await _client.client
          .from(_tableName)
          .delete()
          .eq('id', productId);
      
      return Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to delete product: $e'));
    }
  }
  
  Stream<List<Product>> watchProducts() {
    return _client.client
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .map((data) => (data as List)
            .map((json) => _mapFromJson(json))
            .toList());
  }
  
  Product _mapFromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      departmentId: json['department_id'] as String,
      partsRequired: Map<String, int>.from(json['parts_required'] as Map),
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
  
  Map<String, dynamic> _mapToJson(Product product) {
    // FIX: Ensure parts_required is not null and is a valid JSONB format
    final partsRequired = product.partsRequired.isNotEmpty 
        ? product.partsRequired 
        : <String, int>{};
    
    return {
      'id': product.id,
      'name': product.name,
      'department_id': product.departmentId,
      'parts_required': partsRequired,
      'created_by': product.createdBy ?? _client.currentUserId,
      'updated_by': product.updatedBy,
      'created_at': product.createdAt.toIso8601String(),
      'updated_at': product.updatedAt?.toIso8601String(),
    };
  }
}

