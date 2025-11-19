import 'package:hive/hive.dart';

part 'product_model.g.dart';

@HiveType(typeId: 2)
class Product extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  Map<String, int> parts;

  @HiveField(3)
  String departmentId; // 🔹 required

  Product({
    required this.id,
    required this.name,
    required this.parts,
    required this.departmentId, // 🔹 required
  });
}
