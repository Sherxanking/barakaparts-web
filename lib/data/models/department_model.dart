import 'package:hive/hive.dart';
part 'department_model.g.dart';

@HiveType(typeId: 0)
class Department extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<String> productIds;

  @HiveField(3)
  Map<String, int> productParts; // 🔹 non-nullable

  Department({
    required this.id,
    required this.name,
    this.productIds = const [],
    this.productParts = const {}, // 🔹 default qiymat
  });
}
