/// Part History entity - Domain layer
/// 
/// Represents a history entry for part quantity changes

class PartHistory {
  final String id;
  final String partId;
  final String userId;
  final String userName; // For display
  final String actionType; // add, update, delete, create
  final int quantityBefore;
  final int quantityAfter;
  final int quantityChange; // Positive for add, negative for remove
  final String? notes;
  final DateTime createdAt;

  const PartHistory({
    required this.id,
    required this.partId,
    required this.userId,
    required this.userName,
    required this.actionType,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.quantityChange,
    this.notes,
    required this.createdAt,
  });

  /// Get human-readable description
  String getDescription() {
    switch (actionType) {
      case 'add':
        return 'Qo\'shildi: +$quantityChange';
      case 'update':
        return 'Yangilandi: $quantityBefore → $quantityAfter';
      case 'create':
        return 'Yaratildi: $quantityAfter';
      case 'delete':
        return 'O\'chirildi';
      default:
        return actionType;
    }
  }

  /// Check if this is an addition
  bool get isAddition => quantityChange > 0;

  /// Check if this is a removal
  bool get isRemoval => quantityChange < 0;
}

















