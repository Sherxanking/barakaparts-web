/// ProductService - Product bilan ishlash uchun business logic
/// 
/// Bu service product CRUD operatsiyalarini, department bo'yicha 
/// filtrlash, qidiruv va tartiblash funksiyalarini boshqaradi.
import 'package:flutter/foundation.dart';
import '../models/product_model.dart' as data;
import 'hive_box_service.dart';
import '../../domain/entities/product.dart' as domain;
import '../../domain/entities/department.dart' as domainDept;
import '../../core/di/service_locator.dart';
import '../../core/utils/either.dart';

class ProductService {
  final HiveBoxService _boxService = HiveBoxService();
  
  // Repository for Supabase sync
  final _productRepository = ServiceLocator.instance.productRepository;

  /// Barcha productlarni olish
  /// FIX: Xavfsiz box kirish - xatolik bo'lsa bo'sh ro'yxat qaytarish
  List<data.Product> getAllProducts() {
    try {
      return _boxService.productsBox.values.toList();
    } catch (e) {
      // Box ochilmagan yoki xatolik bo'lsa bo'sh ro'yxat qaytarish
      return [];
    }
  }

  /// ID bo'yicha product topish
  data.Product? getProductById(String id) {
    // Hive boxda ID key emas, shuning uchun barcha elementlarni qidirish kerak
    try {
      return _boxService.productsBox.values.firstWhere(
        (product) => product.id == id,
        orElse: () => throw StateError('Product not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if product name already exists (case-insensitive, trimmed)
  /// Returns true if duplicate found, false otherwise
  bool _hasDuplicateName(String name, {String? excludeId}) {
    final normalizedName = name.trim().toLowerCase();
    try {
      return _boxService.productsBox.values.any((existingProduct) {
        if (excludeId != null && existingProduct.id == excludeId) {
          return false; // Exclude current item when editing
        }
        return existingProduct.name.trim().toLowerCase() == normalizedName;
      });
    } catch (e) {
      debugPrint('⚠️ Error checking duplicate product name: $e');
      return false; // If check fails, allow creation (server will catch it)
    }
  }

  /// Product qo'shish
  /// FIX: Hive va Supabase'ga yozish (realtime sync uchun)
  /// FIX: Department mavjudligini tekshirish
  /// FIX: Duplicate name validation (case-insensitive, trimmed)
  Future<bool> addProduct(data.Product product) async {
    try {
      // 0. Local validation: Check for duplicate name
      if (_hasDuplicateName(product.name)) {
        debugPrint('❌ Duplicate product name detected: ${product.name}');
        return false; // Will be handled by UI with proper error message
      }
      
      // FIX: Department Supabase'da mavjudligini tekshirish
      // Eslatma: Department repository hozircha ServiceLocator'da yo'q
      // Shuning uchun faqat xatolik xabarini yaxshilaymiz
      try {
        final department = _boxService.departmentsBox.values.firstWhere(
          (dept) => dept.id == product.departmentId,
        );
        debugPrint('✅ Department found in Hive: ${department.name}');
      } catch (e) {
        debugPrint('⚠️ Department not found in Hive: ${product.departmentId}');
        // Department topilmadi, lekin davom etamiz
      }
      
      // 1. Supabase'ga yozish (realtime sync uchun)
      final domainProduct = domain.Product(
        id: product.id,
        name: product.name,
        departmentId: product.departmentId,
        partsRequired: product.parts,
        createdAt: DateTime.now(),
      );
      
      final result = await _productRepository.createProduct(domainProduct);
      
      return result.fold(
        (failure) {
          debugPrint('❌ Failed to create product in Supabase: ${failure.message}');
          // FIX: Foreign key constraint xatosi bo'lsa, aniqroq xabar
          if (failure.message.contains('foreign key constraint') || 
              failure.message.contains('departments')) {
            debugPrint('❌ Department does not exist in Supabase. Please sync departments first.');
          }
          // Supabase'ga yozish xato bo'lsa ham Hive'ga yozishga harakat qilamiz
          try {
            _boxService.productsBox.add(product);
            return true; // Hive'ga yozildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (createdProduct) {
          // 2. Hive'ga ham yozish (offline cache uchun)
          try {
            _boxService.productsBox.add(product);
            debugPrint('✅ Product created in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Product created in Supabase but failed to save to Hive: $e');
            return true; // Supabase'ga yozildi, bu asosiy
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in addProduct: $e');
      return false;
    }
  }

  /// Product yangilash
  /// FIX: Hive va Supabase'ga yozish (realtime sync uchun)
  /// FIX: Duplicate name validation (case-insensitive, trimmed)
  Future<bool> updateProduct(data.Product updatedProduct) async {
    try {
      // 0. Local validation: Check for duplicate name (exclude current product)
      if (_hasDuplicateName(updatedProduct.name, excludeId: updatedProduct.id)) {
        debugPrint('❌ Duplicate product name detected: ${updatedProduct.name}');
        return false; // Will be handled by UI with proper error message
      }
      
      // FIX: Hive boxdan mavjud productni topish
      final existingProduct = getProductById(updatedProduct.id);
      if (existingProduct == null) {
        return false; // Product topilmadi
      }
      
      // 1. Supabase'ga yozish (realtime sync uchun)
      final domainProduct = domain.Product(
        id: updatedProduct.id,
        name: updatedProduct.name,
        departmentId: updatedProduct.departmentId,
        partsRequired: updatedProduct.parts,
        createdAt: DateTime.now(),
      );
      
      final result = await _productRepository.updateProduct(domainProduct);
      
      return result.fold(
        (failure) async {
          debugPrint('❌ Failed to update product in Supabase: ${failure.message}');
          // Supabase'ga yozish xato bo'lsa ham Hive'ga yozishga harakat qilamiz
          try {
            existingProduct.name = updatedProduct.name;
            existingProduct.departmentId = updatedProduct.departmentId;
            existingProduct.parts = Map<String, int>.from(updatedProduct.parts)
              ..removeWhere((key, value) => value <= 0);
            await existingProduct.save();
            return true; // Hive'ga yozildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (updated) async {
          // 2. Hive'ga ham yozish (offline cache uchun)
          try {
            existingProduct.name = updatedProduct.name;
            existingProduct.departmentId = updatedProduct.departmentId;
            existingProduct.parts = Map<String, int>.from(updatedProduct.parts)
              ..removeWhere((key, value) => value <= 0);
            await existingProduct.save();
            debugPrint('✅ Product updated in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Product updated in Supabase but failed to save to Hive: $e');
            return true; // Supabase'ga yozildi, bu asosiy
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in updateProduct: $e');
      return false;
    }
  }

  /// Product o'chirish
  /// FIX: Index tekshiruvi va Supabase'ga ham o'chirish
  Future<bool> deleteProduct(int index) async {
    try {
      if (index < 0 || index >= _boxService.productsBox.length) {
        return false;
      }
      
      final product = _boxService.productsBox.getAt(index);
      if (product == null) return false;
      
      final productId = product.id;
      
      // 1. Supabase'dan o'chirish (realtime sync uchun)
      final result = await _productRepository.deleteProduct(productId);
      
      return result.fold(
        (failure) async {
          debugPrint('❌ Failed to delete product in Supabase: ${failure.message}');
          // Supabase'dan o'chirish xato bo'lsa ham Hive'dan o'chirishga harakat qilamiz
          try {
            await _boxService.productsBox.deleteAt(index);
            return true; // Hive'dan o'chirildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (_) async {
          // 2. Hive'dan ham o'chirish (offline cache uchun)
          try {
            await _boxService.productsBox.deleteAt(index);
            debugPrint('✅ Product deleted from both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Product deleted from Supabase but failed to delete from Hive: $e');
            return true; // Supabase'dan o'chirildi, bu asosiy
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in deleteProduct: $e');
      return false;
    }
  }

  /// Department bo'yicha productlarni filtrlash
  List<data.Product> getProductsByDepartment(String departmentId) {
    return getAllProducts().where((product) {
      return product.departmentId == departmentId;
    }).toList();
  }

  /// Qidiruv - nom bo'yicha
  List<data.Product> searchProducts(String query) {
    if (query.isEmpty) return getAllProducts();
    
    final lowerQuery = query.toLowerCase();
    return getAllProducts().where((product) {
      return product.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Qidiruv va filtrlash birga
  List<data.Product> searchAndFilterProducts({
    String? query,
    String? departmentId,
  }) {
    List<data.Product> products = getAllProducts();

    // Department bo'yicha filtrlash
    if (departmentId != null && departmentId.isNotEmpty) {
      products = products.where((p) => p.departmentId == departmentId).toList();
    }

    // Qidiruv
    if (query != null && query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      products = products.where((p) {
        return p.name.toLowerCase().contains(lowerQuery);
      }).toList();
    }

    return products;
  }

  /// Tartiblash - nom bo'yicha
  List<data.Product> sortProducts(List<data.Product> products, bool ascending) {
    final sorted = List<data.Product>.from(products);
    sorted.sort((a, b) {
      final comparison = a.name.compareTo(b.name);
      return ascending ? comparison : -comparison;
    });
    return sorted;
  }
}

