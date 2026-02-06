/// Order entity - Domain layer
/// 
/// Represents a production order.

class Order {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final int completedQuantity; // Qisman completed uchun
  final String departmentId;
  final String status; // pending, in_progress, completed, rejected
  final String? workerId; // Kim bajarayapti
  final String? completedBy; // Kim tugatdi
  final String? createdBy;
  final String? approvedBy;
  final String? soldTo; // Kimga sotilgan
  final String? notes; // Izoh
  final Map<String, int>? partsRequired; // Order yaratilgan vaqtidagi part miqdorlari (snapshot)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt; // Order tugatilgan vaqt
  final DateTime? startedAt; // Order boshlangan vaqt
  final double? durationHours; // Order bajarishga ketgan vaqt (soatda)

  const Order({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.completedQuantity = 0,
    required this.departmentId,
    required this.status,
    this.workerId,
    this.completedBy,
    this.createdBy,
    this.approvedBy,
    this.soldTo,
    this.notes,
    this.partsRequired, // Order yaratilgan vaqtidagi part miqdorlari
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.startedAt,
    this.durationHours,
  });

  /// Check if order is pending
  bool get isPending => status == 'pending';
  
  /// Check if order is in progress
  bool get isInProgress => status == 'in_progress';
  
  /// Check if order is completed
  bool get isCompleted => status == 'completed';
  
  /// Check if order is rejected
  bool get isRejected => status == 'rejected';
  
  /// Check if order is partially completed
  bool get isPartiallyCompleted => completedQuantity > 0 && completedQuantity < quantity;
  
  /// Get remaining quantity
  int get remainingQuantity => quantity - completedQuantity;
  
  /// Check if order can be approved
  bool canBeApproved() => isPending;
  
  /// Check if order can be started (assigned to worker)
  bool canBeStarted() => isPending || isInProgress;
  
  /// Check if order can be completed (partially or fully)
  bool canBeCompleted() => isInProgress || isPartiallyCompleted;
  
  /// Check if order can be rejected
  bool canBeRejected() => isPending || isInProgress;
  
  /// Check if order can be assigned to worker
  bool canAssignWorker() => isPending || isInProgress;

  Order copyWith({
    String? id,
    String? productId,
    String? productName,
    int? quantity,
    int? completedQuantity,
    String? departmentId,
    String? status,
    String? workerId,
    String? completedBy,
    String? createdBy,
    String? approvedBy,
    String? soldTo,
    String? notes,
    Map<String, int>? partsRequired,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? startedAt,
    double? durationHours,
  }) {
    return Order(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      completedQuantity: completedQuantity ?? this.completedQuantity,
      departmentId: departmentId ?? this.departmentId,
      status: status ?? this.status,
      workerId: workerId ?? this.workerId,
      completedBy: completedBy ?? this.completedBy,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      soldTo: soldTo ?? this.soldTo,
      notes: notes ?? this.notes,
      partsRequired: partsRequired ?? this.partsRequired,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      startedAt: startedAt ?? this.startedAt,
      durationHours: durationHours ?? this.durationHours,
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

  /// Calculate duration in hours between startedAt and completedAt
  double? getDurationInHours() {
    if (startedAt != null && completedAt != null) {
      final difference = completedAt!.difference(startedAt!);
      return difference.inMinutes / 60.0; // Convert minutes to hours
    }
    return null;
  }

  /// Check if order is fully completed
  bool get isFullyCompleted => completedQuantity >= quantity && status == 'completed';

  /// Check if order has started
  bool get hasStarted => startedAt != null;

}

