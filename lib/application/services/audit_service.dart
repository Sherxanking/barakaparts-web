/// Audit Service
/// 
/// Automatically logs all changes in the system for audit trail.

import '../../domain/entities/log.dart';
import '../../domain/repositories/log_repository.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../core/utils/constants.dart';

class AuditService {
  final LogRepository _logRepository;
  
  AuditService(this._logRepository);
  
  /// Log a create action
  Future<Either<Failure, void>> logCreate({
    required String userId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> afterValue,
  }) async {
    return _logAction(
      userId: userId,
      actionType: AppConstants.logActionCreate,
      entityType: entityType,
      entityId: entityId,
      afterValue: afterValue,
    );
  }
  
  /// Log an update action
  Future<Either<Failure, void>> logUpdate({
    required String userId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? beforeValue,
    required Map<String, dynamic> afterValue,
  }) async {
    return _logAction(
      userId: userId,
      actionType: AppConstants.logActionUpdate,
      entityType: entityType,
      entityId: entityId,
      beforeValue: beforeValue,
      afterValue: afterValue,
    );
  }
  
  /// Log a delete action
  Future<Either<Failure, void>> logDelete({
    required String userId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? beforeValue,
  }) async {
    return _logAction(
      userId: userId,
      actionType: AppConstants.logActionDelete,
      entityType: entityType,
      entityId: entityId,
      beforeValue: beforeValue,
    );
  }
  
  /// Log an approve action
  Future<Either<Failure, void>> logApprove({
    required String userId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? beforeValue,
    required Map<String, dynamic> afterValue,
  }) async {
    return _logAction(
      userId: userId,
      actionType: AppConstants.logActionApprove,
      entityType: entityType,
      entityId: entityId,
      beforeValue: beforeValue,
      afterValue: afterValue,
    );
  }
  
  /// Log a reject action
  Future<Either<Failure, void>> logReject({
    required String userId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? beforeValue,
    required Map<String, dynamic> afterValue,
  }) async {
    return _logAction(
      userId: userId,
      actionType: AppConstants.logActionReject,
      entityType: entityType,
      entityId: entityId,
      beforeValue: beforeValue,
      afterValue: afterValue,
    );
  }
  
  /// Internal method to create log entry
  Future<Either<Failure, void>> _logAction({
    required String userId,
    required String actionType,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? beforeValue,
    Map<String, dynamic>? afterValue,
  }) async {
    final log = Log(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      actionType: actionType,
      entityType: entityType,
      entityId: entityId,
      beforeValue: beforeValue,
      afterValue: afterValue,
      createdAt: DateTime.now(),
    );
    
    final result = await _logRepository.createLog(log);
    return result.fold(
      (failure) => Left(failure),
      (_) => Right(null),
    );
  }
}

