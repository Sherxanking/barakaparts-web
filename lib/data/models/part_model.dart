import 'package:hive/hive.dart';

part 'part_model.g.dart';

@HiveType(typeId: 1)
class PartModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int quantity;

  @HiveField(3)
  String status;

  @HiveField(4)
  String? imagePath; // Rasm fayl yo'li (ixtiyoriy)

  @HiveField(5)
  int minQuantity; // Minimal miqdor (threshold) - shu miqdordan kam bo'lsa eslatma

  PartModel({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.status = "available",
    this.imagePath,
    this.minQuantity = 3, // Default minimal miqdor
  });
}
