/// Supabase Part History Datasource
/// 
/// Handles part history operations

import '../../domain/entities/part_history.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import 'supabase_client.dart';

class SupabasePartHistoryDatasource {
  final AppSupabaseClient _client = AppSupabaseClient.instance;
  
  String get _tableName => 'part_history';
  
  /// Create history entry
  Future<Either<Failure, PartHistory>> createHistory({
    required String partId,
    required String userId,
    required String actionType,
    required int quantityBefore,
    required int quantityAfter,
    String? notes,
  }) async {
    try {
      final quantityChange = quantityAfter - quantityBefore;
      
      final json = {
        'part_id': partId,
        'user_id': userId,
        'action_type': actionType,
        'quantity_before': quantityBefore,
        'quantity_after': quantityAfter,
        'quantity_change': quantityChange,
        'notes': notes,
      };
      
      final response = await _client.client
          .from(_tableName)
          .insert(json)
          .select()
          .single();
      
      // Get user name
      final userResult = await _client.client
          .from('users')
          .select('name')
          .eq('id', userId)
          .single();
      
      final userName = userResult['name'] as String? ?? 'Unknown';
      
      return Right(_mapFromJson(response, userName));
    } catch (e) {
      return Left(ServerFailure('Failed to create history: $e'));
    }
  }
  
  /// Get history for a specific part
  Future<Either<Failure, List<PartHistory>>> getPartHistory(String partId) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select('''
            *,
            users:user_id (
              name
            )
          ''')
          .eq('part_id', partId)
          .order('created_at', ascending: false);
      
      final history = (response as List).map((json) {
        final userName = json['users'] != null && json['users'] is Map
            ? (json['users'] as Map)['name'] as String? ?? 'Unknown'
            : 'Unknown';
        return _mapFromJson(json, userName);
      }).toList();
      
      return Right(history);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch history: $e'));
    }
  }
  
  /// Get all history (for admin)
  Future<Either<Failure, List<PartHistory>>> getAllHistory() async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select('''
            *,
            users:user_id (
              name
            )
          ''')
          .order('created_at', ascending: false)
          .limit(100);
      
      final history = (response as List).map((json) {
        final userName = json['users'] != null && json['users'] is Map
            ? (json['users'] as Map)['name'] as String? ?? 'Unknown'
            : 'Unknown';
        return _mapFromJson(json, userName);
      }).toList();
      
      return Right(history);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch history: $e'));
    }
  }
  
  PartHistory _mapFromJson(Map<String, dynamic> json, String userName) {
    return PartHistory(
      id: json['id'] as String,
      partId: json['part_id'] as String,
      userId: json['user_id'] as String,
      userName: userName,
      actionType: json['action_type'] as String,
      quantityBefore: json['quantity_before'] as int? ?? 0,
      quantityAfter: json['quantity_after'] as int? ?? 0,
      quantityChange: json['quantity_change'] as int? ?? 0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

















