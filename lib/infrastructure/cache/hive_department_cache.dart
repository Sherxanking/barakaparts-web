/// Hive Department Cache
/// 
/// Simple cache implementation for offline support
/// Stores Department entities in Hive for offline access

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/department.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

class HiveDepartmentCache {
  static const String _boxName = 'departmentsCache';
  Box<Map>? _box;

  /// Initialize cache box
  Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<Map>(_boxName);
      return;
    }
    _box = await Hive.openBox<Map>(_boxName);
  }

  /// Get cached departments
  Future<Either<Failure, List<Department>>> getCachedDepartments() async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      final departments = <Department>[];
      
      for (var key in box.keys) {
        final data = box.get(key) as Map<String, dynamic>?;
        if (data != null) {
          try {
            departments.add(_mapToDepartment(data));
          } catch (e) {
            // Skip invalid entries
            continue;
          }
        }
      }
      
      return Right(departments);
    } catch (e) {
      return Left(CacheFailure('Failed to get cached departments: $e'));
    }
  }

  /// Save departments to cache
  Future<void> saveDepartments(List<Department> departments) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.clear();
      
      for (var department in departments) {
        await box.put(department.id, _departmentToMap(department));
      }
    } catch (e) {
      // Cache errors should not break the app
      debugPrint('⚠️ Cache save error: $e');
    }
  }

  /// Update single department in cache
  Future<void> updateDepartment(Department department) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.put(department.id, _departmentToMap(department));
    } catch (e) {
      debugPrint('⚠️ Cache update error: $e');
    }
  }

  /// Delete department from cache
  Future<void> deleteDepartment(String departmentId) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.delete(departmentId);
    } catch (e) {
      debugPrint('⚠️ Cache delete error: $e');
    }
  }

  /// Map to Department entity
  Department _mapToDepartment(Map<String, dynamic> data) {
    return Department(
      id: data['id'] as String,
      name: data['name'] as String,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : null,
    );
  }

  /// Department entity to Map
  Map<String, dynamic> _departmentToMap(Department department) {
    return {
      'id': department.id,
      'name': department.name,
      if (department.createdAt != null)
        'created_at': department.createdAt!.toIso8601String(),
    };
  }
}

















