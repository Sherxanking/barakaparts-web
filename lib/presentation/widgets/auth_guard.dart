/// Auth Guard Widget
/// 
/// WHY: Ensures user is authenticated before showing protected content.
/// Automatically redirects to login if not authenticated.
/// Uses global auth state service for consistent behavior.

import 'package:flutter/material.dart';
import '../../core/services/auth_state_service.dart';
import '../../domain/entities/user.dart' as domain;
import '../pages/auth/login_page.dart';
import '../pages/home_page.dart';

/// Auth Guard Widget
/// 
/// Shows child widget only if user is authenticated.
/// Otherwise redirects to login page.
class AuthGuard extends StatefulWidget {
  final Widget child;
  
  const AuthGuard({
    super.key,
    required this.child,
  });

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  domain.User? _currentUser;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  /// Check initial auth state
  Future<void> _checkAuthState() async {
    final authService = AuthStateService();
    
    // Get current user
    _currentUser = authService.currentUser;
    
    // Listen to auth state changes
    authService.onAuthStateChange((user) {
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _isChecking = false;
      });
    });
    
    // If no user initially, wait a bit for auth service to initialize
    if (_currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _currentUser = authService.currentUser;
          _isChecking = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // Show loading while checking auth state
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUser == null) {
      // Not authenticated - show login
      return const LoginPage();
    }

    // Authenticated - show protected content
    return widget.child;
  }
}











