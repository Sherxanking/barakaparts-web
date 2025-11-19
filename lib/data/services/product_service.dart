/// ProductService - Product bilan ishlash uchun business logic
/// 
/// Bu service product CRUD operatsiyalarini, department bo'yicha 
/// filtrlash, qidiruv va tartiblash funksiyalarini boshqaradi.
import '../models/product_model.dart';
import 'hive_box_service.dart';

class ProductService {
  final HiveBoxService _boxService = HiveBoxService();

  /// Barcha productlarni olish
  /// FIX: Xavfsiz box kirish - xatolik bo'lsa bo'sh ro'yxat qaytarish
  List<Product> getAllProducts() {
    try {
      return _boxService.productsBox.values.toList();
    } catch (e) {
      // Box ochilmagan yoki xatolik bo'lsa bo'sh ro'yxat qaytarish
      return [];
    }
  }

  /// ID bo'yicha product topish
  Product? getProductById(String id) {
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

  /// Product qo'shish
  /// FIX: Xatolikni tutish va xavfsiz qo'shish
  Future<bool> addProduct(Product product) async {
    try {
      await _boxService.productsBox.add(product);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Product yangilash
  /// FIX: Xatolikni tutish va xavfsiz yangilash
  Future<bool> updateProduct(Product product) async {
    try {
      await product.save();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Product o'chirish
  /// FIX: Index tekshiruvi va xatolikni tutish
  Future<bool> deleteProduct(int index) async {
    try {
      if (index >= 0 && index < _boxService.productsBox.length) {
        await _boxService.productsBox.deleteAt(index);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Department bo'yicha productlarni filtrlash
  List<Product> getProductsByDepartment(String departmentId) {
    return getAllProducts().where((product) {
      return product.departmentId == departmentId;
    }).toList();
  }

  /// Qidiruv - nom bo'yicha
  List<Product> searchProducts(String query) {
    if (query.isEmpty) return getAllProducts();
    
    final lowerQuery = query.toLowerCase();
    return getAllProducts().where((product) {
      return product.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Qidiruv va filtrlash birga
  List<Product> searchAndFilterProducts({
    String? query,
    String? departmentId,
  }) {
    List<Product> products = getAllProducts();

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
  List<Product> sortProducts(List<Product> products, bool ascending) {
    final sorted = List<Product>.from(products);
    sorted.sort((a, b) {
      final comparison = a.name.compareTo(b.name);
      return ascending ? comparison : -comparison;
    });
    return sorted;
  }
}

