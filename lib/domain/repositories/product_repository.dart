/// Product repository interface - Domain layer

import '../entities/product.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

abstract class ProductRepository {
  /// Get all products
  Future<Either<Failure, List<Product>>> getAllProducts();
  
  /// Get product by ID
  Future<Either<Failure, Product?>> getProductById(String productId);
  
  /// Get products by department
  Future<Either<Failure, List<Product>>> getProductsByDepartment(String departmentId);
  
  /// Search products by name
  Future<Either<Failure, List<Product>>> searchProducts(String query);
  
  /// Create a new product
  Future<Either<Failure, Product>> createProduct(Product product);
  
  /// Update an existing product
  Future<Either<Failure, Product>> updateProduct(Product product);
  
  /// Delete a product
  Future<Either<Failure, void>> deleteProduct(String productId);
  
  /// Stream products for real-time updates
  Stream<Either<Failure, List<Product>>> watchProducts();
}

