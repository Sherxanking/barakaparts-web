/// Application-wide constants
/// 
/// WHY: Business logic constants (roles, statuses, etc.)
/// For Supabase configuration, see lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation
  
  // Cache keys
  static const String cacheUserKey = 'current_user';
  static const String cacheLocaleKey = 'app_locale';
  
  // User roles
  static const String roleWorker = 'worker';
  static const String roleManager = 'manager';
  static const String roleBoss = 'boss';
  static const String roleSupplier = 'supplier';
  
  // Order statuses
  static const String orderStatusPending = 'pending';
  static const String orderStatusCompleted = 'completed';
  static const String orderStatusRejected = 'rejected';
  
  // Part statuses
  static const String partStatusAvailable = 'available';
  static const String partStatusLowStock = 'low_stock';
  static const String partStatusOutOfStock = 'out_of_stock';
  
  // Log action types
  static const String logActionCreate = 'create';
  static const String logActionUpdate = 'update';
  static const String logActionDelete = 'delete';
  static const String logActionApprove = 'approve';
  static const String logActionReject = 'reject';
  
  // Entity types for logging
  static const String entityTypePart = 'part';
  static const String entityTypeProduct = 'product';
  static const String entityTypeOrder = 'order';
  static const String entityTypeDepartment = 'department';
  static const String entityTypeUser = 'user';
}

