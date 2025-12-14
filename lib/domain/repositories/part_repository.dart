/// Part repository interface - Domain layer

import '../entities/part.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

abstract class PartRepository {
  /// Get all parts
  Future<Either<Failure, List<Part>>> getAllParts();
  
  /// Get part by ID
  Future<Either<Failure, Part?>> getPartById(String partId);
  
  /// Search parts by name
  Future<Either<Failure, List<Part>>> searchParts(String query);
  
  /// Create a new part
  Future<Either<Failure, Part>> createPart(Part part);
  
  /// Update an existing part
  Future<Either<Failure, Part>> updatePart(Part part);
  
  /// Delete a part
  Future<Either<Failure, void>> deletePart(String partId);
  
  /// Stream parts for real-time updates
  Stream<Either<Failure, List<Part>>> watchParts();
  
  /// Get low stock parts
  Future<Either<Failure, List<Part>>> getLowStockParts();
}

