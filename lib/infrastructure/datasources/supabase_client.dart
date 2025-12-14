/// Supabase client initialization
/// 
/// WHY: Centralized Supabase client setup using AppConstants instead of deprecated getters
/// All Supabase client access goes through this singleton instance.
/// 
/// REFACTOR: Fixed to use AppConstants instead of deprecated client.supabaseUrl/supabaseKey getters

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';

/// App Supabase Service - Centralized Supabase client singleton
/// 
/// WHY: Prevents name collision with SupabaseClient from supabase_flutter package
/// Provides safe, centralized access to Supabase client instance
class AppSupabaseClient {
  static AppSupabaseClient? _instance;
  static AppSupabaseClient get instance {
    _instance ??= AppSupabaseClient._();
    return _instance!;
  }
  
  AppSupabaseClient._();
  
  /// Initialize Supabase
  /// 
  /// WHY: Uses AppConstants instead of deprecated getters
  /// ⚠️ SECURITY: Only ANON key is used! Service role key is NEVER used here!
  static Future<void> initialize() async {
    try {
      // Get URL and key from centralized constants
      final url = AppConstants.supabaseUrl;
      final anonKey = AppConstants.supabaseAnonKey;
      
      // ⚠️ SECURITY: Service role key check
      if (anonKey.contains('service_role')) {
        throw Exception('❌ Service role key is not allowed! Only anon key should be used!');
      }
      
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      
      debugPrint('✅ Supabase initialized successfully');
      debugPrint('   URL: $url');
    } catch (e) {
      debugPrint('❌ Supabase initialization error: $e');
      rethrow; // Re-throw to allow app to handle gracefully
    }
  }
  
  /// Check if Supabase is initialized
  /// 
  /// WHY: Safe check before accessing client
  static bool get isInitialized {
    try {
      return Supabase.instance.isInitialized;
    } catch (e) {
      return false;
    }
  }
  
  /// Get Supabase client (from supabase_flutter package)
  /// 
  /// WHY: Centralized access point for all Supabase operations
  /// ⚠️ SECURITY: Throws error if not initialized to prevent crashes
  SupabaseClient get client {
    if (!Supabase.instance.isInitialized) {
      throw StateError(
        'Supabase is not initialized. Call AppSupabaseClient.initialize() first.'
      );
    }
    return Supabase.instance.client;
  }
  
  /// Get current authenticated user
  /// 
  /// WHY: Safe access to current user with null handling
  User? get currentUser {
    try {
      if (!Supabase.instance.isInitialized) {
        return null;
      }
      return client.auth.currentUser;
    } catch (e) {
      debugPrint('⚠️ Error getting current user: $e');
      return null;
    }
  }
  
  /// Get current user ID
  /// 
  /// WHY: Convenience getter for user ID
  String? get currentUserId => currentUser?.id;
  
  /// Get Supabase URL from constants (not from client)
  /// 
  /// WHY: Replaces deprecated client.supabaseUrl getter
  /// Use this instead of client.supabaseUrl
  String get supabaseUrl => AppConstants.supabaseUrl;
}

