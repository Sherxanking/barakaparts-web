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

  Order({
    required this.id,
    required this.departmentId,
    required this.productName,
    required this.quantity,
    this.status = "new",
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
