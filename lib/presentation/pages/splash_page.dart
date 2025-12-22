/// Splash Page - Startup initialization and auth guard
/// 
/// WHY: Ensures Supabase and Hive are initialized before app starts,
/// checks for existing session, and navigates to appropriate page (Home or Auth).
/// Prevents crashes from accessing uninitialized services.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/datasources/supabase_client.dart';
import '../../domain/repositories/user_repository.dart';
import '../../infrastructure/datasources/supabase_user_datasource.dart';
import '../../infrastructure/repositories/user_repository_impl.dart';
import '../../core/services/auth_state_service.dart';
import '../../domain/entities/user.dart' as domain;
import 'home_page.dart';
import 'auth/login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _isInitializing = true;
  String? _errorMessage;
  domain.User? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initialize app: check Supabase session and fetch user profile
  /// PERFORMANCE: Optimized with timeout and non-blocking operations
  Future<void> _initializeApp() async {
    try {
      // PERFORMANCE: Show UI immediately, don't wait
      // Minimum splash time for smooth UX (reduced from 500ms)
      await Future.delayed(const Duration(milliseconds: 300));

      // PERFORMANCE: Wait for Supabase initialization with timeout
      // WHY: Prevents infinite waiting if Supabase is slow
      int retryCount = 0;
      const maxRetries = 10;
      const retryDelay = Duration(milliseconds: 200);

      while (!AppSupabaseClient.isInitialized && retryCount < maxRetries) {
        await Future.delayed(retryDelay);
        retryCount++;
      }

      // Check if Supabase is initialized after retries
      if (!AppSupabaseClient.isInitialized) {
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
        });
        // Go to auth even if Supabase not ready (offline mode)
        _navigateToAuth();
        return;
      }

      // FIX: Use global auth state service for consistent auth checking
      // WHY: Global service handles OAuth users and session persistence correctly
      final authService = AuthStateService();
      final currentUser = authService.currentUser;
      
      if (currentUser != null) {
        // User is authenticated - go to home
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
          _currentUser = currentUser;
        });
        _navigateToHome();
      } else {
        // No user - check session and load profile
        // FIX: Use currentSession directly (synchronous getter in Supabase SDK 2.x)
        // WHY: currentSession is not async, no need for Future.value() or timeout
        final client = AppSupabaseClient.instance;
        Session? session;
        
        try {
          // WHY: currentSession is a synchronous getter, returns Session? directly
          session = client.client.auth.currentSession;
          debugPrint('🔍 Session check: ${session != null ? "exists" : "null"}');
        } catch (e) {
          debugPrint('⚠️ Error checking session: $e');
          session = null;
        }
        
        if (session != null && session.user != null) {
          // Session exists - wait for auth service to load profile with timeout
          debugPrint('✅ Session found, loading user profile...');
          
          bool profileLoaded = false;
          
          // Listen to auth state changes with timeout
          authService.onAuthStateChange((user) {
            if (!mounted || profileLoaded) return;
            
            if (user != null) {
              profileLoaded = true;
              if (!mounted) return;
              setState(() {
                _isInitializing = false;
                _currentUser = user;
              });
              _navigateToHome();
            }
          });
          
          // Wait for profile to load (with timeout)
          try {
            await Future.delayed(const Duration(seconds: 3));
            
            // Check again after delay
            if (!mounted) return;
            final updatedUser = authService.currentUser;
            if (updatedUser != null && !profileLoaded) {
              profileLoaded = true;
              if (!mounted) return;
              setState(() {
                _isInitializing = false;
                _currentUser = updatedUser;
              });
              _navigateToHome();
            } else if (updatedUser == null && !profileLoaded) {
              // Still no user after timeout - try auto-create one more time
              if (!mounted) return;
              debugPrint('⚠️ Profile still not loaded, attempting final auto-create...');
              
              // Try to auto-create profile one more time
              try {
                final client = AppSupabaseClient.instance;
                final session = client.client.auth.currentSession;
                if (session != null && session.user != null) {
                  final datasource = SupabaseUserDatasource();
                  
                  // OAuth callback removed - only email/password authentication is supported
                  // If session exists but profile not found, go to auth
                  if (!mounted) return;
                  setState(() {
                    _isInitializing = false;
                  });
                  _navigateToAuth();
                } else {
                  // No session - go to auth
                  if (!mounted) return;
                  setState(() {
                    _isInitializing = false;
                  });
                  _navigateToAuth();
                }
              } catch (e) {
                debugPrint('⚠️ Final auto-create error: $e');
                if (!mounted) return;
                setState(() {
                  _isInitializing = false;
                });
                _navigateToAuth();
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error waiting for profile: $e');
            if (!mounted) return;
            setState(() {
              _isInitializing = false;
            });
            // Error loading profile - try to navigate to auth instead of showing error
            debugPrint('⚠️ Error loading profile: $e');
            if (!mounted) return;
            setState(() {
              _isInitializing = false;
            });
            _navigateToAuth(); // Go to login instead of showing error
          }
        } else {
          // No session - go to auth immediately
          if (!mounted) return;
          setState(() {
            _isInitializing = false;
          });
          _navigateToAuth();
        }
      }
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Failed to initialize app. Please try again.';
      });
      // On error, go to auth after short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _navigateToAuth();
        }
      });
    }
  }

  /// Load user profile with timeout to prevent infinite loading
  /// PERFORMANCE: Optimized with timeout and error handling
  /// NOTE: This method is kept for backward compatibility but may not be used
  @Deprecated('Use AuthStateService instead')
  Future<void> _loadUserProfileWithTimeout() async {
    try {
      final userRepository = UserRepositoryImpl(
        datasource: SupabaseUserDatasource(),
      );
      
      // PERFORMANCE: Fetch user with timeout
      final userResult = await userRepository.getCurrentUser()
          .timeout(const Duration(seconds: 5));
      
      // Extract user from Either safely without exposing domain types
      domain.User? user;
      try {
        user = userResult.fold(
          (failure) => throw Exception('Profile not found'),
          (u) => u,
        );
      } catch (e) {
        debugPrint('⚠️ User profile not found: $e');
        // OAuth callback removed - only email/password authentication is supported
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
        });
        _navigateToAuth();
        return;
      }
      
      // User found or created
      if (user != null) {
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
          _currentUser = user;
        });
        _navigateToHome();
      } else {
        // User is null - go to auth
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
        });
        _navigateToAuth();
      }
    } on TimeoutException {
      debugPrint('⚠️ User profile load timeout');
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });
      _navigateToAuth();
    } catch (e) {
      debugPrint('❌ User profile load error: $e');
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });
      _navigateToAuth();
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  void _navigateToAuth() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon
              Icon(
                Icons.inventory_2,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              // App Name
              Text(
                'Baraka Parts',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Inventory Management',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 48),
              // Loading indicator
              if (_isInitializing)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              if (!_isInitializing && _errorMessage != null) ...[
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade300,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

