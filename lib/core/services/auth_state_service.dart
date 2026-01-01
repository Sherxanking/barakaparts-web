/// Global Auth State Service
/// 
/// WHY: Centralized auth state management ensures consistent navigation
/// after login/logout across the entire app lifecycle.
/// 
/// This service listens to Supabase auth state changes globally and
/// provides callbacks for navigation handling.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/datasources/supabase_client.dart';
import '../../domain/entities/user.dart' as domain;
import '../../infrastructure/datasources/supabase_user_datasource.dart';
import '../../infrastructure/repositories/user_repository_impl.dart';
import '../../domain/repositories/user_repository.dart';

/// Global auth state service singleton
/// 
/// WHY: Single source of truth for auth state across the app
class AuthStateService {
  static final AuthStateService _instance = AuthStateService._internal();
  factory AuthStateService() => _instance;
  AuthStateService._internal();

  StreamSubscription<AuthState>? _authStateSubscription;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  /// Current authenticated user
  domain.User? _currentUser;
  domain.User? get currentUser => _currentUser;
  
  /// Auth state change callbacks
  final List<Function(domain.User?)> _onAuthStateChangeCallbacks = [];
  
  /// Initialize auth state listener
  /// 
  /// WHY: Sets up global listener for auth state changes
  /// This ensures navigation happens correctly after OAuth redirects
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Listen to auth state changes globally
      _authStateSubscription = AppSupabaseClient.instance.client.auth.onAuthStateChange.listen(
        _handleAuthStateChange,
      );
      
      // Check initial auth state
      await _checkInitialAuthState();
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ AuthStateService initialization error: $e');
    }
  }
  
  /// Check initial auth state on app startup
  /// 
  /// WHY: Ensures we know if user is logged in when app starts
  /// FIX: Retry mechanism qo'shildi - session mavjud bo'lsa, profile load qilishga bir necha marta urinish
  Future<void> _checkInitialAuthState() async {
    try {
      final session = AppSupabaseClient.instance.client.auth.currentSession;
      if (session != null) {
        debugPrint('✅ Session found on startup, loading user profile...');
        // User has session - fetch profile with retries
        await _loadUserProfileWithRetries();
      } else {
        debugPrint('⚠️ No session found on startup');
        // No session - clear user
        _currentUser = null;
        _notifyAuthStateChange(null);
      }
    } catch (e) {
      debugPrint('⚠️ Error checking initial auth state: $e');
      _currentUser = null;
      _notifyAuthStateChange(null);
    }
  }
  
  /// Load user profile with retries
  /// FIX: Session mavjud bo'lsa, profile load qilishga bir necha marta urinish
  Future<void> _loadUserProfileWithRetries() async {
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 500);
    
    for (int i = 0; i < maxRetries; i++) {
      try {
        await _loadUserProfile();
        
        // Agar user profile yuklandi, to'xtatish
        if (_currentUser != null) {
          debugPrint('✅ User profile loaded successfully on attempt ${i + 1}');
          return;
        }
        
        // Agar hali user profile yuklanmagan bo'lsa, qayta urinish
        if (i < maxRetries - 1) {
          debugPrint('⚠️ User profile not loaded, retrying... (attempt ${i + 1}/$maxRetries)');
          await Future.delayed(retryDelay);
        }
      } catch (e) {
        debugPrint('⚠️ Error loading user profile (attempt ${i + 1}): $e');
        if (i < maxRetries - 1) {
          await Future.delayed(retryDelay);
        }
      }
    }
    
    // Agar barcha urinishlar muvaffaqiyatsiz bo'lsa
    if (_currentUser == null) {
      debugPrint('❌ Failed to load user profile after $maxRetries attempts');
      // Session mavjud bo'lsa ham, profile topilmasa, auto-create qilishga harakat qilish
      try {
        final session = AppSupabaseClient.instance.client.auth.currentSession;
        if (session != null && session.user != null) {
          debugPrint('🔄 Attempting to auto-create user profile...');
          final userRepository = UserRepositoryImpl(
            datasource: SupabaseUserDatasource(),
          );
          
          // Auto-create user profile
          final email = session.user!.email ?? '';
          final name = session.user!.userMetadata?['name'] as String? ?? email.split('@')[0];
          final role = _getRoleForTestAccount(email) ?? 'worker';
          
          final autoCreateResult = await userRepository.getCurrentUser();
          autoCreateResult.fold(
            (failure) {
              debugPrint('⚠️ Auto-create failed: ${failure.message}');
            },
            (user) {
              if (user != null) {
                _currentUser = user;
                _notifyAuthStateChange(user);
                debugPrint('✅ User profile auto-created: ${user.name}');
              }
            },
          );
        }
      } catch (e) {
        debugPrint('❌ Auto-create error: $e');
      }
    }
  }
  
  /// Get role for test accounts (helper method)
  String? _getRoleForTestAccount(String email) {
    final emailLower = email.toLowerCase();
    if (emailLower == 'manager@test.com') {
      return 'manager';
    } else if (emailLower == 'boss@test.com') {
      return 'boss';
    }
    return null;
  }
  
  /// Handle auth state changes from Supabase
  /// 
  /// WHY: Responds to login/logout events and updates app state
  /// FIX: Ignore OAuth sign-ins - only email/password authentication is supported
  Future<void> _handleAuthStateChange(AuthState state) async {
    final event = state.event;
    final session = state.session;
    
    debugPrint('🔐 Auth state changed: $event');
    
    // FIX: Ignore OAuth sign-ins - only email/password authentication is supported
    if (session != null && session.user != null) {
      final provider = session.user!.appMetadata['provider'] as String?;
      if (provider != null && provider != 'email') {
        debugPrint('⚠️ OAuth sign-in detected (provider: $provider) - ignoring and signing out');
        // Sign out OAuth users immediately
        try {
          await AppSupabaseClient.instance.client.auth.signOut();
        } catch (e) {
          debugPrint('⚠️ Error signing out OAuth user: $e');
        }
        _currentUser = null;
        _notifyAuthStateChange(null);
        return;
      }
    }
    
    if (event == AuthChangeEvent.signedIn && session != null) {
      // User signed in - load profile with timeout
      await _loadUserProfileWithTimeout();
    } else if (event == AuthChangeEvent.signedOut) {
      // User signed out - clear user
      _currentUser = null;
      _notifyAuthStateChange(null);
    } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
      // Token refreshed - ensure profile is loaded
      if (_currentUser == null) {
        await _loadUserProfileWithTimeout();
      }
    }
  }
  
  /// Load user profile with timeout and retries
  /// 
  /// WHY: OAuth redirects might take time, need to poll for session
  Future<void> _loadUserProfileWithTimeout() async {
    const maxRetries = 5;
    const retryDelay = Duration(seconds: 2);
    const timeout = Duration(seconds: 10);
    
    try {
      // First, check if session exists
      var session = AppSupabaseClient.instance.client.auth.currentSession;
      
      // If no session, poll for it (OAuth might be processing)
      if (session == null) {
        debugPrint('⚠️ No session found, polling for session...');
        for (int i = 0; i < maxRetries; i++) {
          await Future.delayed(retryDelay);
          session = AppSupabaseClient.instance.client.auth.currentSession;
          if (session != null) {
            debugPrint('✅ Session found after ${i + 1} retries');
            break;
          }
        }
      }
      
      if (session == null) {
        debugPrint('❌ No session found after polling');
        _currentUser = null;
        _notifyAuthStateChange(null);
        return;
      }
      
      // Load profile with timeout
      await _loadUserProfile().timeout(timeout);
    } on TimeoutException {
      debugPrint('⚠️ Profile load timeout');
      _currentUser = null;
      _notifyAuthStateChange(null);
    } catch (e) {
      debugPrint('❌ Error in profile load with timeout: $e');
      _currentUser = null;
      _notifyAuthStateChange(null);
    }
  }
  
  /// Load user profile from database
  /// 
  /// WHY: Fetches user profile after auth state change
  /// FIX: Force refresh from public.users table (role source of truth)
  /// NOTE: Role MUST come from public.users.role, NOT from auth metadata
  Future<void> _loadUserProfile() async {
    try {
      final userRepository = UserRepositoryImpl(
        datasource: SupabaseUserDatasource(),
      );
      
      // FIX: Force refresh from public.users table
      // WHY: Role source of truth is public.users.role, not auth metadata
      final result = await userRepository.getCurrentUser();
      
      result.fold(
        (failure) {
          debugPrint('⚠️ Failed to load user profile: ${failure.message}');
          // Profile not found - user needs to login
          _currentUser = null;
          _notifyAuthStateChange(null);
        },
        (user) {
          if (user != null) {
            // FIX: Ensure role is from public.users (not metadata)
            _currentUser = user;
            _notifyAuthStateChange(user);
            debugPrint('✅ User profile loaded from public.users: ${user.name} (role: ${user.role})');
          } else {
            // User profile not found - user needs to login
            _currentUser = null;
            _notifyAuthStateChange(null);
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error loading user profile: $e');
      _currentUser = null;
      _notifyAuthStateChange(null);
    }
  }
  
  // OAuth callback removed - only email/password authentication is supported
  
  /// Register callback for auth state changes
  /// 
  /// WHY: Allows widgets to react to auth state changes
  void onAuthStateChange(Function(domain.User?) callback) {
    _onAuthStateChangeCallbacks.add(callback);
    // Immediately call with current state
    callback(_currentUser);
  }
  
  /// Remove auth state change callback
  void removeAuthStateChangeCallback(Function(domain.User?) callback) {
    _onAuthStateChangeCallbacks.remove(callback);
  }
  
  /// Notify all callbacks of auth state change
  void _notifyAuthStateChange(domain.User? user) {
    for (final callback in _onAuthStateChangeCallbacks) {
      try {
        callback(user);
      } catch (e) {
        debugPrint('❌ Auth state callback error: $e');
      }
    }
  }
  
  /// Sign out current user
  /// 
  /// WHY: Centralized sign out that clears all state
  Future<void> signOut() async {
    try {
      await AppSupabaseClient.instance.client.auth.signOut();
      _currentUser = null;
      _notifyAuthStateChange(null);
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
    }
  }
  
  /// Dispose resources
  /// 
  /// WHY: Clean up subscriptions when app closes
  void dispose() {
    _authStateSubscription?.cancel();
    _authStateSubscription = null;
    _onAuthStateChangeCallbacks.clear();
    _isInitialized = false;
  }
}

