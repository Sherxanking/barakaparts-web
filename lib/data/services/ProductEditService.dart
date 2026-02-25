import '../../domain/entities/ProductEditResult.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../services/department_service.dart';
import '../services/part_service.dart';

class ProductEditService {
  final ProductService productService;
  final DepartmentService departmentService;
  final PartService partService;

  ProductEditService({
    required this.productService,
    required this.departmentService,
    required this.partService,
  });

  Future<ProductEditResult> saveProduct({
    required Product product,
    required String name,
    required String departmentId,
    required Map<String, int> parts,
  }) async {
    try {
      // Update product
      final updatedProduct = Product(
        id: product.id,
        name: name,
        departmentId: departmentId,
        parts: parts,
      );

      await productService.updateProduct(updatedProduct);

      return ProductEditResult.success();
    } catch (e) {
      return ProductEditResult.error(e.toString());
    }
  }

  Future<ProductEditResult> createProduct({
    required String name,
    required String departmentId,
    required Map<String, int> parts,
  }) async {
    try {
      // Create new product
      final newProduct = Product(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        departmentId: departmentId,
        parts: parts,
      );

      await productService.addProduct(newProduct);

      return ProductEditResult.success();
    } catch (e) {
      return ProductEditResult.error(e.toString());
    }
  }
}
