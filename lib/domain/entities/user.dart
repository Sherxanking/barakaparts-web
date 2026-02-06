/// User entity - Domain layer
/// 
/// Pure domain entity without any framework dependencies.
/// Represents a user in the system with role-based access.

class User {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String role; // worker, manager, boss, supplier, cashier, warehouse
  final String? position; // lavozimi: sotuvchi, omborchi, kassir, vs
  final String? departmentId; // Manager uchun bo'lim ID
  final DateTime createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    required this.role,
    this.position,
    this.departmentId,
    required this.createdAt,
    this.updatedAt,
  });

  /// Check if user has worker role
  bool get isWorker => role == 'worker';
  
  /// Check if user has manager role
  bool get isManager => role == 'manager';
  
  /// Check if user has boss role
  bool get isBoss => role == 'boss';
  
  /// Check if user has supplier role
  bool get isSupplier => role == 'supplier';
  
  /// Check if user has cashier role
  bool get isCashier => role == 'cashier';
  
  /// Check if user has warehouse role
  bool get isWarehouse => role == 'warehouse';
  
  /// Get user's full title
  String get fullTitle => '${position ?? role} - $name';
  
  /// Check if user can edit parts (create, update)
  /// WHY: Only managers and boss can modify parts, workers are read-only
  bool canEditParts() {
    return isManager || isBoss;
  }
  
  /// Check if user can create parts
  /// WHY: Only managers and boss can create new parts
  bool canCreateParts() {
    return isManager || isBoss;
  }
  
  /// Check if user can delete parts
  /// WHY: Only boss can delete parts
  bool canDeleteParts() {
    return isBoss;
  }
  
  /// Check if user can approve orders
  bool canApproveOrders() {
    return isManager || isBoss;
  }
  
  /// Check if user can delete data
  bool canDeleteData() {
    return isBoss;
  }
  
  /// Check if user can see all logs
  bool canSeeAllLogs() {
    return isManager || isBoss;
  }
  
  /// Check if user can add large batches
  bool canAddLargeBatches() {
    return isSupplier || isBoss;
  }

  /// Check if user is a courier/driver
  bool get isCourier {
    return role == 'courier' || role == 'driver';
  }

  /// Check if user can manage orders (for couriers)
  bool get canManageOrders {
    return isCourier || isWorker || isManager || isBoss;
  }

  /// Check if user can complete orders (for couriers)
  bool get canCompleteOrders {
    return isCourier || isWorker || isManager || isBoss;
  }

  /// Create a copy of this user with updated fields
  User copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? role,
    String? position,
    String? departmentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      position: position ?? this.position,
      departmentId: departmentId ?? this.departmentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

