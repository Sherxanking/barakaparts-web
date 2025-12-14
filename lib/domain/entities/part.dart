/// Part entity - Domain layer
/// 
/// Represents an inventory part/component.

class Part {
  final String id;
  final String name;
  final int quantity;
  final int minQuantity;
  final String? imagePath;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Part({
    required this.id,
    required this.name,
    required this.quantity,
    required this.minQuantity,
    this.imagePath,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    this.updatedAt,
  });

  /// Check if part is low on stock
  bool get isLowStock => quantity <= minQuantity;
  
  /// Check if part is out of stock
  bool get isOutOfStock => quantity <= 0;
  
  /// Get stock status
  String get status {
    if (isOutOfStock) return 'out_of_stock';
    if (isLowStock) return 'low_stock';
    return 'available';
  }

  Part copyWith({
    String? id,
    String? name,
    int? quantity,
    int? minQuantity,
    String? imagePath,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Part(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      imagePath: imagePath ?? this.imagePath,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Part &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

