/// User entity - Domain layer
/// 
/// Pure domain entity without any framework dependencies.
/// Represents a user in the system with role-based access.

class User {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String role; // worker, manager, boss, supplier
  final String? departmentId; // Manager uchun bo'lim ID
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    required this.role,
    this.departmentId,
    required this.createdAt,
  });

  /// Check if user has worker role
  bool get isWorker => role == 'worker';
  
  /// Check if user has manager role
  bool get isManager => role == 'manager';
  
  /// Check if user has boss role
  bool get isBoss => role == 'boss';
  
  /// Check if user has supplier role
  bool get isSupplier => role == 'supplier';
  
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

