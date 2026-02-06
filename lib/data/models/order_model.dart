import 'package:hive/hive.dart';
part 'order_model.g.dart';

@HiveType(typeId: 3)
class Order extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String departmentId;

  @HiveField(2)
  String productName;

  @HiveField(3)
  int quantity;

  @HiveField(4)
  String status;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  String? soldTo; // Kimga sotilgan

  @HiveField(7)
  String? workerId; // Kim bajarayapti (yangi qo'shildi)

  @HiveField(8)
  int completedQuantity; // Qisman completed uchun (yangi qo'shildi)

  @HiveField(9)
  DateTime? updatedAt; // Yangilangan vaqt (yangi qo'shildi)

  @HiveField(10)
  DateTime? completedAt; // Tugallangan vaqt (yangi qo'shildi)

  @HiveField(11)
  String? completedBy; // Kim tugatgan (yangi qo'shildi)

  @HiveField(12)
  String? notes; // Izoh (yangi qo'shildi)

  @HiveField(13)
  Map? partsRequired; // Order yaratilgan vaqtidagi part miqdorlari (snapshot) (yangi qo'shildi)

  @HiveField(14)
  DateTime? startedAt; // Order boshlangan vaqt (yangi qo'shildi)

  @HiveField(15)
  double? durationHours; // Order bajarishga ketgan vaqt (yangi qo'shildi)

  Order({
    required this.id,
    required this.departmentId,
    required this.productName,
    required this.quantity,
    this.status = "new",
    DateTime? createdAt,
    this.soldTo,
    this.workerId,
    this.completedQuantity = 0,
    this.updatedAt,
    this.completedAt,
    this.completedBy,
    this.notes,
    this.partsRequired,
    this.startedAt,
    this.durationHours,
  }) : createdAt = createdAt ?? DateTime.now();
}
