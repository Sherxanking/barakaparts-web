/// Order entity - Domain layer
/// 
/// Represents a production order.

class Order {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final String departmentId;
  final String status; // pending, completed, rejected
  final String? createdBy;
  final String? approvedBy;
  final String? soldTo; // Kimga sotilgan
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Order({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.departmentId,
    required this.status,
    this.createdBy,
    this.approvedBy,
    this.soldTo,
    required this.createdAt,
    this.updatedAt,
  });

  /// Check if order is pending
  bool get isPending => status == 'pending';
  
  /// Check if order is completed
  bool get isCompleted => status == 'completed';
  
  /// Check if order is rejected
  bool get isRejected => status == 'rejected';
  
  /// Check if order can be approved
  bool canBeApproved() => isPending;
  
  /// Check if order can be rejected
  bool canBeRejected() => isPending;

  Order copyWith({
    String? id,
    String? productId,
    String? productName,
    int? quantity,
    String? departmentId,
    String? status,
    String? createdBy,
    String? approvedBy,
    String? soldTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      departmentId: departmentId ?? this.departmentId,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      soldTo: soldTo ?? this.soldTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

