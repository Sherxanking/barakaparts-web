/// Product Sale entity - Domain layer
/// 
/// Represents a product sale record

class ProductSale {
  final String id;
  final String productId;
  final String productName;
  final String departmentId;
  final String departmentName;
  final int quantity;
  final String? orderId;
  final String? soldBy; // User ID
  final String? soldByName; // User name for display
  final DateTime soldAt;

  const ProductSale({
    required this.id,
    required this.productId,
    required this.productName,
    required this.departmentId,
    required this.departmentName,
    required this.quantity,
    this.orderId,
    this.soldBy,
    this.soldByName,
    required this.soldAt,
  });

  /// Get human-readable description
  String getDescription() {
    return '$quantity ta "$productName" → $departmentName';
  }
}

















