/// Product entity - Domain layer
/// 
/// Represents a product that requires parts.

class Product {
  final String id;
  final String name;
  final String departmentId;
  final Map<String, int> partsRequired; // part_id -> required_quantity
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.name,
    required this.departmentId,
    required this.partsRequired,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get total number of unique parts required
  int get totalPartsCount => partsRequired.length;
  
  /// Get total quantity of all parts required
  int get totalPartsQuantity {
    return partsRequired.values.fold(0, (sum, qty) => sum + qty);
  }

  Product copyWith({
    String? id,
    String? name,
    String? departmentId,
    Map<String, int>? partsRequired,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      departmentId: departmentId ?? this.departmentId,
      partsRequired: partsRequired ?? this.partsRequired,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

