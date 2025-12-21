/// Supabase Department Datasource
/// 
/// Handles all Supabase operations for departments.

import 'package:flutter/foundation.dart';
import '../../domain/entities/department.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import 'supabase_client.dart';

class SupabaseDepartmentDatasource {
  final AppSupabaseClient _client = AppSupabaseClient.instance;
  
  String get _tableName => 'departments';
  
  /// Get all departments from Supabase
  Future<Either<Failure, List<Department>>> getAllDepartments() async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);
      
      final departments = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(departments);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch departments: $e'));
    }
  }
  
  /// Get department by ID
  Future<Either<Failure, Department?>> getDepartmentById(String departmentId) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .eq('id', departmentId)
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      if (e.toString().contains('PGRST116')) {
        return Right(null); // Not found
      }
      return Left(ServerFailure('Failed to fetch department: $e'));
    }
  }
  
  /// Search departments
  Future<Either<Failure, List<Department>>> searchDepartments(String query) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .ilike('name', '%$query%')
          .order('name');
      
      final departments = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(departments);
    } catch (e) {
      return Left(ServerFailure('Failed to search departments: $e'));
    }
  }
  
  /// Create department
  Future<Either<Failure, Department>> createDepartment(Department department) async {
    try {
      if (department.name.isEmpty) {
        return Left<Failure, Department>(ValidationFailure('Department name cannot be empty'));
      }
      
      final json = _mapToJson(department);
      final response = await _client.client
          .from(_tableName)
          .insert(json)
          .select()
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      return Left(ServerFailure('Failed to create department: $e'));
    }
  }
  
  /// Update department
  Future<Either<Failure, Department>> updateDepartment(Department department) async {
    try {
      if (department.name.isEmpty) {
        return Left<Failure, Department>(ValidationFailure('Department name cannot be empty'));
      }
      
      final json = _mapToJson(department);
      final response = await _client.client
          .from(_tableName)
          .update(json)
          .eq('id', department.id)
          .select()
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      return Left(ServerFailure('Failed to update department: $e'));
    }
  }
  
  /// Delete department
  Future<Either<Failure, void>> deleteDepartment(String departmentId) async {
    try {
      await _client.client
          .from(_tableName)
          .delete()
          .eq('id', departmentId);
      
      return Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to delete department: $e'));
    }
  }
  
  /// Stream departments for real-time updates
  Stream<List<Department>> watchDepartments() {
    return _client.client
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .map((data) => (data as List)
            .map((json) => _mapFromJson(json))
            .toList());
  }
  
  /// Map JSON to Department entity
  Department _mapFromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
  
  /// Map Department entity to JSON
  Map<String, dynamic> _mapToJson(Department department) {
    return {
      'id': department.id,
      'name': department.name,
      if (department.createdAt != null)
        'created_at': department.createdAt!.toIso8601String(),
    };
  }
}
