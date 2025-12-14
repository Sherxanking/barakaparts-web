/// Department entity - Domain layer
/// 
/// Represents a department in the organization.

class Department {
  final String id;
  final String name;
  final DateTime? createdAt;

  const Department({
    required this.id,
    required this.name,
    this.createdAt,
  });

  Department copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Department &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

