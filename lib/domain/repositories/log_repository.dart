/// Log repository interface - Domain layer

import '../entities/log.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

abstract class LogRepository {
  /// Create a log entry
  Future<Either<Failure, Log>> createLog(Log log);
  
  /// Get logs for a specific user
  Future<Either<Failure, List<Log>>> getLogsByUser(String userId);
  
  /// Get logs for a specific entity
  Future<Either<Failure, List<Log>>> getLogsByEntity(String entityType, String entityId);
  
  /// Get all logs (for managers/boss only)
  Future<Either<Failure, List<Log>>> getAllLogs({
    String? userId,
    String? entityType,
    DateTime? startDate,
    DateTime? endDate,
  });
  
  /// Stream logs for real-time updates
  Stream<Either<Failure, List<Log>>> watchLogs();
}

