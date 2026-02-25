/// Result class for product editing operations
class ProductEditResult {
  final bool success;
  final String? errorMessage;

  ProductEditResult({required this.success, this.errorMessage});

  factory ProductEditResult.success() {
    return ProductEditResult(success: true);
  }

  factory ProductEditResult.error(String message) {
    return ProductEditResult(success: false, errorMessage: message);
  }
}
