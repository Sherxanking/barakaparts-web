/// User permissions helper - Domain layer
/// 
/// Centralized permission checking logic based on user roles.

import '../entities/user.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

class UserPermissions {
  /// Check if user can edit parts
  static bool canEditParts(User? user) {
    if (user == null) return false;
    return user.canEditParts();
  }
  
  /// Check if user can approve orders
  static bool canApproveOrders(User? user) {
    if (user == null) return false;
    return user.canApproveOrders();
  }
  
  /// Check if user can delete data
  static bool canDeleteData(User? user) {
    if (user == null) return false;
    return user.canDeleteData();
  }
  
  /// Check if user can see all logs
  static bool canSeeAllLogs(User? user) {
    if (user == null) return false;
    return user.canSeeAllLogs();
  }
  
  /// Check if user can add large batches
  static bool canAddLargeBatches(User? user) {
    if (user == null) return false;
    return user.canAddLargeBatches();
  }
  
  /// Check if user can create orders
  static bool canCreateOrders(User? user) {
    // All authenticated users can create orders
    return user != null;
  }
  
  /// Check if user can edit products
  static bool canEditProducts(User? user) {
    if (user == null) return false;
    return user.isManager || user.isBoss;
  }
  
  /// Check if user can delete users
  static bool canDeleteUsers(User? user) {
    if (user == null) return false;
    return user.isBoss;
  }
  
  /// Check if user can see analytics
  static bool canSeeAnalytics(User? user) {
    if (user == null) return false;
    return user.isBoss || user.isManager;
  }
  
  /// Validate permission and return failure if not allowed
  static Either<Failure, void> requirePermission(
    User? user,
    bool Function(User?) checkPermission,
    String errorMessage,
  ) {
    if (user == null) {
      return Left(AuthFailure('User not authenticated'));
    }
    
    if (!checkPermission(user)) {
      return Left(PermissionFailure(errorMessage));
    }
    
    return Right(null);
  }
}

