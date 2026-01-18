/// Department Repository Implementation
/// 
/// Combines Supabase (source of truth) with Hive cache (offline support).

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/department.dart';
import '../../domain/repositories/department_repository.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../datasources/supabase_department_datasource.dart';
import '../cache/hive_department_cache.dart';
import '../../data/models/department_model.dart' as model;

class DepartmentRepositoryImpl implements DepartmentRepository {
  final SupabaseDepartmentDatasource _supabaseDatasource;
  final HiveDepartmentCache _cache;
  
  DepartmentRepositoryImpl({
    required SupabaseDepartmentDatasource supabaseDatasource,
    required HiveDepartmentCache cache,
  })  : _supabaseDatasource = supabaseDatasource,
        _cache = cache;

  @override
  Future<Either<Failure, List<Department>>> getAllDepartments() async {
    try {
      // Try Supabase first
      final result = await _supabaseDatasource.getAllDepartments();
      return result.fold(
        (failure) async {
          // If Supabase fails, try cache
          final cachedResult = await _cache.getCachedDepartments();
          return cachedResult.fold(
            (_) => Left(failure),
            (cachedDepartments) => Right(cachedDepartments),
          );
        },
        (departments) async {
          // Update cache with fresh data
          await _cache.saveDepartments(departments);
          return Right(departments);
        },
      );
    } catch (e) {
      // Fallback to cache
      final cachedResult = await _cache.getCachedDepartments();
      return cachedResult.fold(
        (_) => Left(UnknownFailure('Unexpected error: $e')),
        (departments) => Right(departments),
      );
    }
  }

  @override
  Future<Either<Failure, Department?>> getDepartmentById(String departmentId) async {
    try {
      final result = await _supabaseDatasource.getDepartmentById(departmentId);
      return result.fold(
        (failure) async {
          // Try cache
          final cachedResult = await _cache.getCachedDepartments();
          return cachedResult.fold(
            (_) => Left(failure),
            (departments) => Right(departments.where((d) => d.id == departmentId).firstOrNull),
          );
        },
        (department) async {
          if (department != null) {
            await _cache.updateDepartment(department);
          }
          return Right(department);
        },
      );
    } catch (e) {
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Department>>> searchDepartments(String query) async {
    try {
      return await _supabaseDatasource.searchDepartments(query);
    } catch (e) {
      // Fallback: search in cache
      final cachedResult = await _cache.getCachedDepartments();
      return cachedResult.fold(
        (failure) => Left(failure),
        (departments) {
          final filtered = departments
              .where((d) => d.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return Right(filtered);
        },
      );
    }
  }

  @override
  Future<Either<Failure, Department>> createDepartment(Department department) async {
    final result = await _supabaseDatasource.createDepartment(department);
    return result.fold(
      (failure) => Left(failure),
      (createdDepartment) async {
        // Update cache
        await _cache.updateDepartment(createdDepartment);
        
        // FIX: Also update departmentsBox for UI sync (ValueListenableBuilder)
        await _updateSingleDepartmentInBox(createdDepartment);
        
        return Right(createdDepartment);
      },
    );
  }

  @override
  Future<Either<Failure, Department>> updateDepartment(Department department) async {
    final result = await _supabaseDatasource.updateDepartment(department);
    return result.fold(
      (failure) => Left(failure),
      (updatedDepartment) async {
        // Update cache
        await _cache.updateDepartment(updatedDepartment);
        
        // FIX: Also update departmentsBox for UI sync (ValueListenableBuilder)
        await _updateSingleDepartmentInBox(updatedDepartment);
        
        return Right(updatedDepartment);
      },
    );
  }
  
  /// Update single department in departmentsBox
  /// FIX: ValueListenableBuilder yangilanishi uchun
  Future<void> _updateSingleDepartmentInBox(Department domainDepartment) async {
    try {
      if (!Hive.isBoxOpen('departmentsBox')) {
        await Hive.openBox<model.Department>('departmentsBox');
      }
      final box = Hive.box<model.Department>('departmentsBox');
      
      final departmentModel = model.Department(
        id: domainDepartment.id,
        name: domainDepartment.name,
        productIds: const [], // Domain entity doesn't have this
        productParts: const {}, // Domain entity doesn't have this
      );
      
      // Mavjud bo'lsa, yangilash; yo'q bo'lsa, qo'shish
      final existingIndex = box.values.toList().indexWhere((d) => d.id == domainDepartment.id);
      if (existingIndex >= 0) {
        // FIX: putAt ishlatish - index bo'yicha yangilash
        await box.putAt(existingIndex, departmentModel);
        debugPrint('✅ Department ${domainDepartment.name} updated in departmentsBox at index $existingIndex');
      } else {
        await box.add(departmentModel);
        debugPrint('✅ Department ${domainDepartment.name} added to departmentsBox');
      }
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error updating department in departmentsBox: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  Future<Either<Failure, void>> deleteDepartment(String departmentId) async {
    final result = await _supabaseDatasource.deleteDepartment(departmentId);
    return result.fold(
      (failure) => Left(failure),
      (_) async {
        // Remove from cache
        await _cache.deleteDepartment(departmentId);
        
        // FIX: Also remove from departmentsBox for UI sync (ValueListenableBuilder)
        await _deleteDepartmentFromBox(departmentId);
        
        return Right(null);
      },
    );
  }
  
  /// Delete department from departmentsBox
  /// FIX: ValueListenableBuilder yangilanishi uchun
  Future<void> _deleteDepartmentFromBox(String departmentId) async {
    try {
      if (!Hive.isBoxOpen('departmentsBox')) {
        await Hive.openBox<model.Department>('departmentsBox');
      }
      final box = Hive.box<model.Department>('departmentsBox');
      
      // Find and delete department by ID
      final existingIndex = box.values.toList().indexWhere((d) => d.id == departmentId);
      if (existingIndex >= 0) {
        await box.deleteAt(existingIndex);
        debugPrint('✅ Department $departmentId deleted from departmentsBox');
      }
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error deleting department from departmentsBox: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  Stream<Either<Failure, List<Department>>> watchDepartments() {
    // WHY: Fixed stream error handling - properly wraps errors in Either
    return _supabaseDatasource.watchDepartments().map((departments) {
      debugPrint('🔄 watchDepartments: Received ${departments.length} departments from Supabase');
      
      // Update cache when data changes (async but don't await - fire and forget)
      _cache.saveDepartments(departments).then((_) {
        debugPrint('✅ Departments cache updated');
      }).catchError((e) {
        // Log cache error but don't fail the stream
        debugPrint('⚠️ Cache update error: $e');
      });
      
      // FIX: Also update departmentsBox for UI sync
      _updateDepartmentsBox(departments).then((_) {
        debugPrint('✅ DepartmentsBox updated from stream');
      }).catchError((e) {
        debugPrint('⚠️ DepartmentsBox update error: $e');
      });
      
      return Right<Failure, List<Department>>(departments);
    }).handleError((error, stackTrace) {
      debugPrint('❌ Departments stream error: $error');
      debugPrint('Stack trace: $stackTrace');
      // Return error as Left
      return Left<Failure, List<Department>>(ServerFailure('Stream error: $error'));
    });
  }
  
  /// Update departmentsBox with domain departments
  /// FIX: ValueListenableBuilder yangilanishi uchun to'g'ri yozish
  Future<void> _updateDepartmentsBox(List<Department> domainDepartments) async {
    try {
      if (!Hive.isBoxOpen('departmentsBox')) {
        await Hive.openBox<model.Department>('departmentsBox');
      }
      final box = Hive.box<model.Department>('departmentsBox');
      
      debugPrint('🔄 Updating departmentsBox with ${domainDepartments.length} departments');
      
      // FIX: Clear va add o'rniga, mavjud elementlarni yangilash yoki qo'shish
      final existingKeys = box.keys.toList();
      final newDepartmentIds = domainDepartments.map((d) => d.id).toSet();
      
      // Eski elementlarni o'chirish (mavjud bo'lmaganlar)
      for (var key in existingKeys) {
        final department = box.get(key);
        if (department != null && !newDepartmentIds.contains(department.id)) {
          await box.delete(key);
        }
      }
      
      // Yangi elementlarni qo'shish yoki yangilash
      // FIX: To'liq yangilash - eski ma'lumotlar qolmasligi uchun
      for (var domainDepartment in domainDepartments) {
        final departmentModel = model.Department(
          id: domainDepartment.id,
          name: domainDepartment.name,
          productIds: const [], // Domain entity doesn't have this
          productParts: const {}, // Domain entity doesn't have this
        );
        
        // Mavjud bo'lsa, yangilash; yo'q bo'lsa, qo'shish
        final existingIndex = box.values.toList().indexWhere((d) => d.id == domainDepartment.id);
        if (existingIndex >= 0) {
          // FIX: putAt ishlatish - index bo'yicha yangilash
          await box.putAt(existingIndex, departmentModel);
        } else {
          await box.add(departmentModel);
        }
      }
      
      debugPrint('✅ DepartmentsBox updated with ${domainDepartments.length} departments');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error updating departmentsBox: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}










