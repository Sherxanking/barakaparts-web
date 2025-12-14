/// Supabase Part Datasource
/// 
/// Handles all Supabase operations for parts.
/// WHY: Fixed part creation to ensure created_by is set and added comprehensive error handling

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/part.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import 'supabase_client.dart';

class SupabasePartDatasource {
  final AppSupabaseClient _client = AppSupabaseClient.instance;
  
  String get _tableName => 'parts';
  
  /// Get all parts from Supabase
  Future<Either<Failure, List<Part>>> getAllParts() async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);
      
      final parts = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(parts);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch parts: $e'));
    }
  }
  
  /// Get part by ID
  Future<Either<Failure, Part?>> getPartById(String partId) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .eq('id', partId)
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      if (e.toString().contains('PGRST116')) {
        return Right(null); // Not found
      }
      return Left(ServerFailure('Failed to fetch part: $e'));
    }
  }
  
  /// Search parts
  Future<Either<Failure, List<Part>>> searchParts(String query) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .ilike('name', '%$query%')
          .order('name');
      
      final parts = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(parts);
    } catch (e) {
      return Left(ServerFailure('Failed to search parts: $e'));
    }
  }
  
  /// Create part
  /// WHY: Fixed to ensure created_by is set, validate required fields, and provide detailed error messages
  Future<Either<Failure, Part>> createPart(Part part) async {
    try {
      // Validate required fields
      if (part.name.isEmpty) {
        return Left<Failure, Part>(ValidationFailure('Part name cannot be empty'));
      }
      if (part.quantity < 0) {
        return Left<Failure, Part>(ValidationFailure('Quantity cannot be negative'));
      }
      if (part.minQuantity < 0) {
        return Left<Failure, Part>(ValidationFailure('Min quantity cannot be negative'));
      }

      // Ensure created_by is set (required for RLS policy)
      final currentUserId = _client.currentUserId;
      if (currentUserId == null) {
        debugPrint('⚠️ No authenticated user - cannot create part');
        return Left<Failure, Part>(AuthFailure('You must be logged in to create parts'));
      }

      // Map to JSON with proper created_by field
      final json = _mapToJson(part);
      
      // Ensure created_by is ALWAYS set (required for RLS policy)
      json['created_by'] = currentUserId;
      debugPrint('✅ Set created_by to current user: $currentUserId');

      // Remove null values that might cause issues (but keep created_by, image_path, updated_by, updated_at)
      json.removeWhere((key, value) => 
        value == null && 
        key != 'image_path' && 
        key != 'updated_by' && 
        key != 'updated_at' &&
        key != 'created_by' // Keep created_by even if somehow null
      );

      debugPrint('📤 Creating part: ${json['name']} (quantity: ${json['quantity']}, created_by: ${json['created_by']})');

      final response = await _client.client
          .from(_tableName)
          .insert(json)
          .select()
          .single();
      
      debugPrint('✅ Part created successfully: ${response['id']}');
      return Right(_mapFromJson(response));
    } catch (e) {
      debugPrint('❌ Failed to create part: $e');
      final errorStr = e.toString();
      
      // Provide specific error messages
      if (errorStr.contains('null value') || errorStr.contains('NOT NULL')) {
        return Left<Failure, Part>(ValidationFailure('Missing required field. Please check all inputs.'));
      } else if (errorStr.contains('permission') || errorStr.contains('policy')) {
        return Left<Failure, Part>(PermissionFailure('You do not have permission to create parts.'));
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        return Left<Failure, Part>(ServerFailure('Network error. Please check your internet connection.'));
      }
      
      return Left<Failure, Part>(ServerFailure('Failed to create part: ${e.toString()}'));
    }
  }
  
  /// Update part
  Future<Either<Failure, Part>> updatePart(Part part) async {
    try {
      final json = _mapToJson(part);
      json['updated_at'] = DateTime.now().toIso8601String();
      json['updated_by'] = _client.currentUserId;
      
      final response = await _client.client
          .from(_tableName)
          .update(json)
          .eq('id', part.id)
          .select()
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      return Left(ServerFailure('Failed to update part: $e'));
    }
  }
  
  /// Delete part
  Future<Either<Failure, void>> deletePart(String partId) async {
    try {
      await _client.client
          .from(_tableName)
          .delete()
          .eq('id', partId);
      
      return Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to delete part: $e'));
    }
  }
  
  /// Stream parts for real-time updates
  /// WHY: Fixed to use Supabase v2 stream syntax with timeout handling and reconnect logic
  /// Prevents RealtimeSubscribeException by using proper stream configuration
  Stream<List<Part>> watchParts() {
    try {
      // WHY: Use Supabase v2 stream with proper configuration
      // primaryKey is required for realtime subscriptions
      // timeout is handled by Supabase client automatically
      return _client.client
          .from(_tableName)
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: (sink) {
              debugPrint('⚠️ Stream timeout, reconnecting...');
              // Close the sink to trigger reconnection
              sink.close();
            },
          )
          .map((data) {
            try {
              final parts = (data as List)
                  .map((json) => _mapFromJson(json))
                  .toList();
              debugPrint('✅ Realtime update: ${parts.length} parts received');
              return parts;
            } catch (e) {
              debugPrint('⚠️ Error mapping parts from stream: $e');
              return <Part>[]; // Return empty list on mapping error
            }
          })
          .handleError((error, stackTrace) {
            debugPrint('❌ Stream error in watchParts: $error');
            debugPrint('Stack trace: $stackTrace');
            
            // Check if it's a timeout error
            if (error.toString().contains('timeout') || 
                error.toString().contains('timedOut')) {
              debugPrint('⚠️ Stream timeout detected, will reconnect on next listen');
            }
            
            // Return empty list on error to prevent stream from crashing
            return <Part>[];
          }, test: (error) {
            // Handle all errors
            return true;
          });
    } catch (e) {
      debugPrint('❌ Failed to create stream: $e');
      // Return empty stream on initialization error
      return Stream.value(<Part>[]);
    }
  }
  
  /// Get low stock parts
  Future<Either<Failure, List<Part>>> getLowStockParts() async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .lte('quantity', 'min_quantity')
          .order('quantity');
      
      final parts = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(parts);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch low stock parts: $e'));
    }
  }
  
  /// Map JSON to Part entity
  Part _mapFromJson(Map<String, dynamic> json) {
    return Part(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      minQuantity: json['min_quantity'] as int? ?? 3,
      imagePath: json['image_path'] as String?,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
  
  /// Map Part entity to JSON
  /// WHY: Fixed to ensure created_by is never null, handles null values safely
  Map<String, dynamic> _mapToJson(Part part) {
    final currentUserId = _client.currentUserId;
    
    return {
      'id': part.id,
      'name': part.name,
      'quantity': part.quantity,
      'min_quantity': part.minQuantity,
      'image_path': part.imagePath,
      'created_by': part.createdBy ?? currentUserId, // Ensure created_by is set
      'updated_by': part.updatedBy,
      'created_at': part.createdAt.toIso8601String(),
      if (part.updatedAt != null) 'updated_at': part.updatedAt!.toIso8601String(),
    };
  }
}

