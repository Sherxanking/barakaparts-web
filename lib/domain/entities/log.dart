/// Log entity - Domain layer
/// 
/// Represents an audit log entry for tracking all changes in the system.

class Log {
  final String id;
  final String userId;
  final String actionType; // create, update, delete, approve, reject
  final String entityType; // part, product, order, department, user
  final String entityId;
  final Map<String, dynamic>? beforeValue; // JSON
  final Map<String, dynamic>? afterValue; // JSON
  final DateTime createdAt;

  const Log({
    required this.id,
    required this.userId,
    required this.actionType,
    required this.entityType,
    required this.entityId,
    this.beforeValue,
    this.afterValue,
    required this.createdAt,
  });

  /// Get a human-readable description of the log
  String getDescription() {
    return '$actionType $entityType ($entityId)';
  }
}

