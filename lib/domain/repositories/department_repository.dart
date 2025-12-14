/// Department repository interface - Domain layer

import '../entities/department.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

abstract class DepartmentRepository {
  /// Get all departments
  Future<Either<Failure, List<Department>>> getAllDepartments();
  
  /// Get department by ID
  Future<Either<Failure, Department?>> getDepartmentById(String departmentId);
  
  /// Search departments by name
  Future<Either<Failure, List<Department>>> searchDepartments(String query);
  
  /// Create a new department
  Future<Either<Failure, Department>> createDepartment(Department department);
  
  /// Update an existing department
  Future<Either<Failure, Department>> updateDepartment(Department department);
  
  /// Delete a department
  Future<Either<Failure, void>> deleteDepartment(String departmentId);
  
  /// Stream departments for real-time updates
  Stream<Either<Failure, List<Department>>> watchDepartments();
}

