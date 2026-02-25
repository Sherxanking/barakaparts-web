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
      // PERFORMANCE: Start with a very short delay for smooth fade-in
      await Future.delayed(const Duration(milliseconds: 50));

      // PERFORMANCE: Fast check for Supabase initialization
      if (!AppSupabaseClient.isInitialized) {
        int retryCount = 0;
        const maxRetries = 5; // Reduced from 10 to 5 for faster fallback
        const retryDelay = Duration(milliseconds: 200);

        while (!AppSupabaseClient.isInitialized && retryCount < maxRetries) {
          await Future.delayed(retryDelay);
          retryCount++;
        }
      }

      // If Supabase still not ready, proceed in offline mode immediately
      if (!AppSupabaseClient.isInitialized) {
        debugPrint('⚠️ Supabase timeout - offline mode');
        if (mounted) {
          setState(() => _isInitializing = false);
          _navigateToHome();
        }
        return;
      }

      final authService = AuthStateService();
      // Fast initialize if needed
      if (!authService.isInitialized) {
        await authService.initialize().timeout(const Duration(seconds: 2), 
          onTimeout: () => debugPrint('⚠️ Auth init timeout'));
      }
      
      final client = AppSupabaseClient.instance;
      final session = client.client.auth.currentSession;
      final currentUser = authService.currentUser;
      
      if (currentUser != null) {
        // We have a user! Go home immediately
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _currentUser = currentUser;
          });
          _navigateToHome();
        }
        return;
      }
      
      // If we have a session but no profile yet, wait briefly
      if (session != null) {
        debugPrint('🔍 Session exists, waiting for profile...');
        // Wait maximum 1 second for the profile to appear in the service
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) return;
          
          if (authService.currentUser != null) {
            setState(() {
              _isInitializing = false;
              _currentUser = authService.currentUser;
            });
            _navigateToHome();
            return;
          }
        }
      }
      
      // No user or failed to load profile - go to home as guest
      if (mounted) {
        setState(() => _isInitializing = false);
        _navigateToHome();
      }
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
        _navigateToHome();
      }
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

