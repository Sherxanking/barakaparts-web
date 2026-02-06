import 'package:hive/hive.dart';

part 'taken_item.g.dart';

@HiveType(typeId: 5)
class TakenItem extends HiveObject {
  @HiveField(0)
  String courierId;

  @HiveField(1)
  int quantity;

  @HiveField(2)
  DateTime takenAt;

  @HiveField(3)
  String? notes; // Izoh (masalan, kim olib ketdi)

  TakenItem({
    required this.courierId,
    required this.quantity,
    DateTime? takenAt,
    this.notes,
  }) : takenAt = takenAt ?? DateTime.now();
}