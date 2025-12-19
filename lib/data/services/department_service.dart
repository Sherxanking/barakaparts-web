/// DepartmentService - Department bilan ishlash uchun business logic
/// 
/// Bu service department CRUD operatsiyalarini, qidiruv, filtrlash 
/// va tartiblash funksiyalarini boshqaradi.
import 'package:flutter/foundation.dart';
import '../models/department_model.dart';
import 'hive_box_service.dart';
import '../../infrastructure/datasources/supabase_client.dart';

class DepartmentService {
  final HiveBoxService _boxService = HiveBoxService();
  final _supabaseClient = AppSupabaseClient.instance.client;

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

  /// Check if department name already exists (case-insensitive, trimmed)
  /// Returns true if duplicate found, false otherwise
  bool _hasDuplicateName(String name, {String? excludeId}) {
    final normalizedName = name.trim().toLowerCase();
    try {
      return _boxService.departmentsBox.values.any((existingDept) {
        if (excludeId != null && existingDept.id == excludeId) {
          return false; // Exclude current item when editing
        }
        return existingDept.name.trim().toLowerCase() == normalizedName;
      });
    } catch (e) {
      debugPrint('⚠️ Error checking duplicate department name: $e');
      return false; // If check fails, allow creation (server will catch it)
    }
  }

  /// Department qo'shish
  /// FIX: Hive va Supabase'ga yozish (realtime sync uchun)
  /// FIX: Duplicate name validation (case-insensitive, trimmed)
  Future<bool> addDepartment(Department department) async {
    try {
      // 0. Local validation: Check for duplicate name
      if (_hasDuplicateName(department.name)) {
        debugPrint('❌ Duplicate department name detected: ${department.name}');
        return false; // Will be handled by UI with proper error message
      }
      
      // 1. Supabase'ga yozish (realtime sync uchun)
      try {
        final response = await _supabaseClient
            .from('departments')
            .insert({
              'id': department.id,
              'name': department.name,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        
        debugPrint('✅ Department created in Supabase: ${response['name']}');
      } catch (e) {
        debugPrint('❌ Failed to create department in Supabase: $e');
        final errorStr = e.toString();
        
        // Check for duplicate name error
        if (errorStr.contains('duplicate key') || 
            errorStr.contains('unique constraint') || 
            errorStr.contains('departments_name_key') ||
            errorStr.contains('idx_departments_name_unique')) {
          debugPrint('❌ Duplicate department name detected by database');
          // Return false to trigger UI error message
          return false;
        }
        
        // Supabase'ga yozish xato bo'lsa ham Hive'ga yozishga harakat qilamiz
        try {
          await _boxService.departmentsBox.add(department);
          return true; // Hive'ga yozildi, lekin sync yo'q
        } catch (hiveE) {
          return false;
        }
      }
      
      // 2. Hive'ga ham yozish (offline cache uchun)
      try {
        await _boxService.departmentsBox.add(department);
        debugPrint('✅ Department created in both Supabase and Hive');
        return true;
      } catch (e) {
        debugPrint('⚠️ Department created in Supabase but failed to save to Hive: $e');
        return true; // Supabase'ga yozildi, bu asosiy
      }
    } catch (e) {
      debugPrint('❌ Error in addDepartment: $e');
      return false;
    }
  }

  /// Department yangilash
  /// FIX: Hive va Supabase'ga yozish (realtime sync uchun)
  /// FIX: Duplicate name validation (case-insensitive, trimmed)
  Future<bool> updateDepartment(Department department) async {
    try {
      // 0. Local validation: Check for duplicate name (exclude current department)
      if (_hasDuplicateName(department.name, excludeId: department.id)) {
        debugPrint('❌ Duplicate department name detected: ${department.name}');
        return false; // Will be handled by UI with proper error message
      }
      
      // 1. Supabase'ga yozish (realtime sync uchun)
      try {
        await _supabaseClient
            .from('departments')
            .update({
              'name': department.name,
            })
            .eq('id', department.id);
        
        debugPrint('✅ Department updated in Supabase: ${department.name}');
      } catch (e) {
        debugPrint('❌ Failed to update department in Supabase: $e');
        final errorStr = e.toString();
        
        // Check for duplicate name error
        if (errorStr.contains('duplicate key') || 
            errorStr.contains('unique constraint') || 
            errorStr.contains('departments_name_key') ||
            errorStr.contains('idx_departments_name_unique')) {
          debugPrint('❌ Duplicate department name detected by database');
          // Return false to trigger UI error message
          return false;
        }
        
        // Supabase'ga yozish xato bo'lsa ham Hive'ga yozishga harakat qilamiz
        try {
          await department.save();
          return true; // Hive'ga yozildi, lekin sync yo'q
        } catch (hiveE) {
          return false;
        }
      }
      
      // 2. Hive'ga ham yozish (offline cache uchun)
      try {
        await department.save();
        debugPrint('✅ Department updated in both Supabase and Hive');
        return true;
      } catch (e) {
        debugPrint('⚠️ Department updated in Supabase but failed to save to Hive: $e');
        return true; // Supabase'ga yozildi, bu asosiy
      }
    } catch (e) {
      debugPrint('❌ Error in updateDepartment: $e');
      return false;
    }
  }

  /// Department o'chirish
  /// FIX: Hive va Supabase'dan o'chirish (realtime sync uchun)
  Future<bool> deleteDepartment(int index) async {
    try {
      if (index >= 0 && index < _boxService.departmentsBox.length) {
        final department = _boxService.departmentsBox.getAt(index);
        if (department == null) {
          return false;
        }
        
        final departmentId = department.id;
        
        // 1. Supabase'dan o'chirish (realtime sync uchun)
        try {
          await _supabaseClient
              .from('departments')
              .delete()
              .eq('id', departmentId);
          
          debugPrint('✅ Department deleted from Supabase: ${department.name}');
        } catch (e) {
          debugPrint('❌ Failed to delete department from Supabase: $e');
          // Supabase'dan o'chirish xato bo'lsa ham Hive'dan o'chirishga harakat qilamiz
          try {
            await _boxService.departmentsBox.deleteAt(index);
            return true; // Hive'dan o'chirildi, lekin sync yo'q
          } catch (hiveE) {
            return false;
          }
        }
        
        // 2. Hive'dan ham o'chirish (offline cache uchun)
        try {
          await _boxService.departmentsBox.deleteAt(index);
          debugPrint('✅ Department deleted from both Supabase and Hive');
          return true;
        } catch (e) {
          debugPrint('⚠️ Department deleted from Supabase but failed to delete from Hive: $e');
          return true; // Supabase'dan o'chirildi, bu asosiy
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error in deleteDepartment: $e');
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

