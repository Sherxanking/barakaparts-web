/// Hive Product Cache
/// 
/// MVP: Simple cache implementation for offline support
/// Stores Product entities in Hive for offline access

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/product.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

class HiveProductCache {
  static const String _boxName = 'productsCache';
  Box<Map>? _box;

  /// Initialize cache box
  Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<Map>(_boxName);
      return;
    }
    _box = await Hive.openBox<Map>(_boxName);
  }

  /// Get cached products
  Future<Either<Failure, List<Product>>> getCachedProducts() async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      final products = <Product>[];
      
      for (var key in box.keys) {
        final data = box.get(key) as Map<String, dynamic>?;
        if (data != null) {
          try {
            products.add(_mapToProduct(data));
          } catch (e) {
            // Skip invalid entries
            continue;
          }
        }
      }
      
      return Right(products);
    } catch (e) {
      return Left(CacheFailure('Failed to get cached products: $e'));
    }
  }

  /// Save products to cache
  Future<void> saveProducts(List<Product> products) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.clear();
      
      for (var product in products) {
        await box.put(product.id, _productToMap(product));
      }
    } catch (e) {
      // Cache errors should not break the app
      debugPrint('⚠️ Cache save error: $e');
    }
  }

  /// Update single product in cache
  Future<void> updateProduct(Product product) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.put(product.id, _productToMap(product));
    } catch (e) {
      debugPrint('⚠️ Cache update error: $e');
    }
  }

  /// Delete product from cache
  Future<void> deleteProduct(String productId) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.delete(productId);
    } catch (e) {
      debugPrint('⚠️ Cache delete error: $e');
    }
  }

  /// Convert Product entity to Map for Hive storage
  Map<String, dynamic> _productToMap(Product product) {
    return {
      'id': product.id,
      'name': product.name,
      'departmentId': product.departmentId,
      'partsRequired': product.partsRequired,
      'createdBy': product.createdBy,
      'updatedBy': product.updatedBy,
      'createdAt': product.createdAt.toIso8601String(),
      'updatedAt': product.updatedAt?.toIso8601String(),
    };
  }

  /// Convert Map from Hive to Product entity
  Product _mapToProduct(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      departmentId: map['departmentId'] as String,
      partsRequired: Map<String, int>.from(map['partsRequired'] as Map),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }
}

