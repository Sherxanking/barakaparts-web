/// Login Page - Secure authentication with email/password only
/// 
/// WHY: Fixed duplicate dispose() methods and added comprehensive crash protection
/// with mounted checks, try/catch blocks, and safe navigation.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../infrastructure/datasources/supabase_user_datasource.dart';
import '../../../infrastructure/datasources/supabase_client.dart';
import '../../../infrastructure/repositories/user_repository_impl.dart';
import '../../pages/home_page.dart';
// RegisterPage removed - registration not supported in MVP
// import 'register_page.dart';
// ResetPasswordPage removed - password reset not supported in MVP
// import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  StreamSubscription? _authStateSubscription;
  
  late final UserRepository _userRepository;

  @override
  void initState() {
    super.initState();
    _userRepository = UserRepositoryImpl(
      datasource: SupabaseUserDatasource(),
    );
  }

  @override
  void dispose() {
    // WHY: Single dispose() method that properly cleans up all resources
    _emailController.dispose();
    _passwordController.dispose();
    _authStateSubscription?.cancel();
    // Note: Global auth state service callbacks are managed by the service itself
    super.dispose();
  }

  // Google Sign-In removed - only email/password authentication is supported

  void _listenToAuthState() {
    if (!mounted) return;
    
    // FIX: Use Supabase.instance.client.auth.onAuthStateChange directly
    // WHY: Ensures we catch auth state changes immediately after OAuth redirect
    // Also poll getSession() up to 10 seconds if needed
    debugPrint('🔐 Setting up auth state listener for OAuth...');
    
    // Remove any existing subscription first
    _authStateSubscription?.cancel();
    
    // Listen to Supabase auth state changes directly
    _authStateSubscription = AppSupabaseClient.instance.client.auth.onAuthStateChange.listen(
      (AuthState state) async {
        if (!mounted) return;
        
        final event = state.event;
        final session = state.session;
        
        debugPrint('🔐 Auth state event: $event, session: ${session != null ? "exists" : "null"}');
        
        if (event == AuthChangeEvent.signedIn && session != null) {
          // FIX: Session exists - use currentSession instead of getSession()
          // WHY: getSession() is not available in current Supabase SDK version
          debugPrint('✅ Signed in event detected, verifying session...');
          
          // FIX: Poll currentSession up to 10 seconds if needed (instead of getSession())
          Session? verifiedSession = session;
          const maxPolls = 5;
          const pollDelay = Duration(seconds: 2);
          
          for (int i = 0; i < maxPolls; i++) {
            try {
              // FIX: Use currentSession instead of getSession()
              verifiedSession = AppSupabaseClient.instance.client.auth.currentSession;
              if (verifiedSession != null) {
                debugPrint('✅ Session verified after ${i + 1} poll(s)');
                break;
              }
            } catch (e) {
              debugPrint('⚠️ Error checking session: $e');
            }
            
            if (i < maxPolls - 1) {
              await Future.delayed(pollDelay);
            }
          }
          
          if (verifiedSession != null) {
            // FIX: Immediately navigate to Home when valid session exists
            debugPrint('✅ Valid session confirmed, navigating to Home...');
            if (!mounted) return;
            
            // Cancel subscription to prevent duplicate navigation
            _authStateSubscription?.cancel();
            
            // Navigate to Home
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          } else {
            // Session is null after polling - show error
            debugPrint('❌ No valid session found after polling');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login failed: No session found. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else if (event == AuthChangeEvent.signedOut) {
          debugPrint('⚠️ Signed out event detected');
          // User signed out - stay on login page
        }
      },
      onError: (error) {
        debugPrint('❌ Auth state listener error: $error');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Future<void> _handleLogin() async {
    if (!mounted) return;
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      final result = await _userRepository.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      result.fold(
        (failure) {
          if (!mounted) return;
          debugPrint('❌ Login xatolik: ${failure.message}');
          
          // Handle email verification error specially
          if (failure.message.contains('EMAIL_NOT_VERIFIED')) {
            _showEmailVerificationDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  failure.message.replaceAll('EMAIL_NOT_VERIFIED: ', ''),
                  style: const TextStyle(fontSize: 14),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          }
        },
        (user) {
          if (!mounted) return;
          debugPrint('✅ Login muvaffaqiyatli: ${user.name} (${user.role})');
          // Navigate to home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEmailVerificationDialog() {
    if (!mounted) return;
    
    final email = _emailController.text.trim();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Not Verified'),
        content: Text(
          email.isNotEmpty
              ? 'Please verify your email address ($email) before signing in. '
                'Check your inbox for the verification link.\n\n'
                'If you didn\'t receive the email, you can resend it.'
              : 'Please verify your email address before signing in. '
                'Check your inbox for the verification link.\n\n'
                'If you didn\'t receive the email, you can resend it.',
        ),
        actions: [
          // Email verification resend removed - test accounts bypass email verification
          TextButton(
            onPressed: () {
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Icon(
                    Icons.inventory_2,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Baraka Parts',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inventory Management System',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Email input
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Password input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          if (!mounted) return;
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  
                  // Forgot password link removed - password reset not supported in MVP
                  // Users must reset password via Supabase Dashboard
                  const SizedBox(height: 16),
                  
                  // Login button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Google Sign-In and Registration removed - only email/password authentication is supported
                  // Users must be created by admin via Supabase Dashboard
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
