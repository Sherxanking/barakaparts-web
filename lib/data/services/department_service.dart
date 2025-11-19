/// DepartmentService - Department bilan ishlash uchun business logic
/// 
/// Bu service department CRUD operatsiyalarini, qidiruv, filtrlash 
/// va tartiblash funksiyalarini boshqaradi.
import '../models/department_model.dart';
import 'hive_box_service.dart';

class DepartmentService {
  final HiveBoxService _boxService = HiveBoxService();

  /// Barcha departmentlarni olish
  /// FIX: Xavfsiz box kirish - xatolik bo'lsa bo'sh ro'yxat qaytarish
  List<Department> getAllDepartments() {
    try {
      return _boxService.departmentsBox.values.toList();
    } catch (e) {
      // Box ochilmagan yoki xatolik bo'lsa bo'sh ro'yxat qaytarish
      return [];
    }
  }

  /// ID bo'yicha department topish
  Department? getDepartmentById(String id) {
    // Hive boxda ID key emas, shuning uchun barcha elementlarni qidirish kerak
    try {
      return _boxService.departmentsBox.values.firstWhere(
        (dept) => dept.id == id,
        orElse: () => throw StateError('Department not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Department qo'shish
  /// FIX: Xatolikni tutish va xavfsiz qo'shish
  Future<bool> addDepartment(Department department) async {
    try {
      await _boxService.departmentsBox.add(department);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Department yangilash
  /// FIX: Xatolikni tutish va xavfsiz yangilash
  Future<bool> updateDepartment(Department department) async {
    try {
      await department.save();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Department o'chirish
  /// FIX: Index tekshiruvi va xatolikni tutish
  Future<bool> deleteDepartment(int index) async {
    try {
      if (index >= 0 && index < _boxService.departmentsBox.length) {
        await _boxService.departmentsBox.deleteAt(index);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Qidiruv - nom bo'yicha
  List<Department> searchDepartments(String query) {
    if (query.isEmpty) return getAllDepartments();
    
    final lowerQuery = query.toLowerCase();
    return getAllDepartments().where((dept) {
      return dept.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Tartiblash - nom bo'yicha
  List<Department> sortDepartments(List<Department> departments, bool ascending) {
    final sorted = List<Department>.from(departments);
    sorted.sort((a, b) {
      final comparison = a.name.compareTo(b.name);
      return ascending ? comparison : -comparison;
    });
    return sorted;
  }

  /// Departmentga product biriktirish
  Future<void> assignProductToDepartment(String departmentId, String productId) async {
    final department = getDepartmentById(departmentId);
    if (department != null && !department.productIds.contains(productId)) {
      department.productIds.add(productId);
      await department.save();
    }
  }

  /// Departmentdan product olib tashlash
  Future<void> removeProductFromDepartment(String departmentId, String productId) async {
    final department = getDepartmentById(departmentId);
    if (department != null) {
      department.productIds.remove(productId);
      await department.save();
    }
  }
}

