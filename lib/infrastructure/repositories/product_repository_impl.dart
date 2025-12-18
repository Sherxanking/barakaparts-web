/// Product Repository Implementation
/// 
/// Combines Supabase (source of truth) with Hive cache (offline support).

import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../datasources/supabase_product_datasource.dart';
import '../cache/hive_product_cache.dart';
import '../../data/models/product_model.dart' as model;

class ProductRepositoryImpl implements ProductRepository {
  final SupabaseProductDatasource _supabaseDatasource;
  final HiveProductCache _cache;
  
  ProductRepositoryImpl({
    required SupabaseProductDatasource supabaseDatasource,
    required HiveProductCache cache,
  })  : _supabaseDatasource = supabaseDatasource,
        _cache = cache;

  @override
  Future<Either<Failure, List<Product>>> getAllProducts() async {
    try {
      // Try Supabase first
      final result = await _supabaseDatasource.getAllProducts();
      return result.fold(
        (failure) async {
          // If Supabase fails, try cache
          final cachedResult = await _cache.getCachedProducts();
          return cachedResult.fold(
            (_) => Left(failure), // Return original failure if cache also fails
            (cachedProducts) => Right(cachedProducts),
          );
        },
        (products) async {
          // Update cache with fresh data
          await _cache.saveProducts(products);
          return Right(products);
        },
      );
    } catch (e) {
      // Fallback to cache
      final cachedResult = await _cache.getCachedProducts();
      return cachedResult.fold(
        (_) => Left(UnknownFailure('Unexpected error: $e')),
        (products) => Right(products),
      );
    }
  }

  @override
  Future<Either<Failure, Product?>> getProductById(String productId) async {
    try {
      final result = await _supabaseDatasource.getProductById(productId);
      return result.fold(
        (failure) async {
          // Try cache
          final cachedResult = await _cache.getCachedProducts();
          return cachedResult.fold(
            (_) => Left(failure),
            (products) => Right(products.where((p) => p.id == productId).firstOrNull),
          );
        },
        (product) async {
          if (product != null) {
            await _cache.updateProduct(product);
          }
          return Right(product);
        },
      );
    } catch (e) {
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getProductsByDepartment(String departmentId) async {
    try {
      final result = await _supabaseDatasource.getProductsByDepartment(departmentId);
      return result.fold(
        (failure) async {
          // Try cache
          final cachedResult = await _cache.getCachedProducts();
          return cachedResult.fold(
            (_) => Left(failure),
            (products) {
              final filtered = products
                  .where((p) => p.departmentId == departmentId)
                  .toList();
              return Right(filtered);
            },
          );
        },
        (products) async {
          // Update cache with filtered products
          await _cache.saveProducts(products);
          return Right(products);
        },
      );
    } catch (e) {
      // Fallback to cache
      final cachedResult = await _cache.getCachedProducts();
      return cachedResult.fold(
        (_) => Left(UnknownFailure('Unexpected error: $e')),
        (products) {
          final filtered = products
              .where((p) => p.departmentId == departmentId)
              .toList();
          return Right(filtered);
        },
      );
    }
  }

  @override
  Future<Either<Failure, List<Product>>> searchProducts(String query) async {
    try {
      return await _supabaseDatasource.searchProducts(query);
    } catch (e) {
      // Fallback: search in cache
      final cachedResult = await _cache.getCachedProducts();
      return cachedResult.fold(
        (failure) => Left(failure),
        (products) {
          final filtered = products
              .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return Right(filtered);
        },
      );
    }
  }

  @override
  Future<Either<Failure, Product>> createProduct(Product product) async {
    final result = await _supabaseDatasource.createProduct(product);
    return result.fold(
      (failure) => Left(failure),
      (createdProduct) async {
        // Update cache
        await _cache.updateProduct(createdProduct);
        return Right(createdProduct);
      },
    );
  }

  @override
  Future<Either<Failure, Product>> updateProduct(Product product) async {
    final result = await _supabaseDatasource.updateProduct(product);
    return result.fold(
      (failure) => Left(failure),
      (updatedProduct) async {
        // Update cache
        await _cache.updateProduct(updatedProduct);
        return Right(updatedProduct);
      },
    );
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String productId) async {
    final result = await _supabaseDatasource.deleteProduct(productId);
    return result.fold(
      (failure) => Left(failure),
      (_) async {
        // Remove from cache
        await _cache.deleteProduct(productId);
        return Right(null);
      },
    );
  }

  @override
  Stream<Either<Failure, List<Product>>> watchProducts() {
    return _supabaseDatasource.watchProducts().map((products) {
      // Update cache when data changes
      _cache.saveProducts(products);
      // FIX: Also update productsBox for UI sync
      _updateProductsBox(products).catchError((e) {
        debugPrint('⚠️ ProductsBox update error: $e');
      });
      return Right<Failure, List<Product>>(products);
    }).handleError((error) {
      return Left<Failure, List<Product>>(ServerFailure('Stream error: $error'));
    });
  }
  
  /// Update productsBox with domain products
  Future<void> _updateProductsBox(List<Product> domainProducts) async {
    try {
      if (!Hive.isBoxOpen('productsBox')) {
        await Hive.openBox<model.Product>('productsBox');
      }
      final box = Hive.box<model.Product>('productsBox');
      await box.clear();
      
      for (var domainProduct in domainProducts) {
        final productModel = model.Product(
          id: domainProduct.id,
          name: domainProduct.name,
          departmentId: domainProduct.departmentId,
          parts: domainProduct.partsRequired,
        );
        await box.add(productModel);
      }
    } catch (e) {
      debugPrint('⚠️ Error updating productsBox: $e');
    }
  }
}




