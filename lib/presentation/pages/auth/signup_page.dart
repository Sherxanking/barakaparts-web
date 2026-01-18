/// Signup Page - User registration with role selection
/// 
/// WHY: Allows new users to create accounts with role selection
/// Supports: Worker, Manager (with department), Boss roles

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/services/auth_state_service.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../infrastructure/datasources/supabase_user_datasource.dart';
import '../../../infrastructure/repositories/user_repository_impl.dart';
import '../../../data/services/hive_box_service.dart';
import '../../../data/models/department_model.dart';
import 'login_page.dart';
import '../../pages/home_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  String _selectedRole = 'worker';
  String? _selectedDepartmentId;
  
  late final UserRepository _userRepository;
  final HiveBoxService _boxService = HiveBoxService();

  @override
  void initState() {
    super.initState();
    _userRepository = UserRepositoryImpl(
      datasource: SupabaseUserDatasource(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Sign up new user
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Password match validation
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Manager must select department
    if (_selectedRole == 'manager' && _selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a department for Manager role'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Trim and validate email before sending
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your email address'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final result = await _userRepository.signUpWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: _selectedRole,
      );

      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration failed: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        },
        (user) async {
          // Update department if Manager
          if (_selectedRole == 'manager' && _selectedDepartmentId != null) {
            try {
              // Wait a bit for user profile to be fully created
              await Future.delayed(const Duration(milliseconds: 500));
              
              final updatedUser = user.copyWith(
                departmentId: _selectedDepartmentId,
              );
              final updateResult = await _userRepository.updateUser(updatedUser);
              updateResult.fold(
                (failure) {
                  debugPrint('⚠️ Failed to update department: ${failure.message}');
                  // Show warning but continue - department can be updated later
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Warning: Department assignment failed. You can update it later in settings.'),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                (updated) {
                  debugPrint('✅ Department assigned to Manager: ${updated.departmentId}');
                },
              );
            } catch (e) {
              debugPrint('⚠️ Error updating department: $e');
              // Continue anyway - department can be updated later
            }
          }

          // Auto login after successful registration
          final loginResult = await _userRepository.signInWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );

          if (!mounted) return;

          loginResult.fold(
            (failure) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Registration successful, but login failed: ${failure.message}'),
                  backgroundColor: Colors.orange,
                ),
              );
              // Navigate to login page
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            (loggedInUser) {
              // Update auth state service
              AuthStateService().initialize();
              
              // Navigate to home
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomePage()),
              );
            },
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
          content: Text('Registration error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                    Icons.person_add,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create Account',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign up to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Name input
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  
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
                      final trimmedValue = value.trim().toLowerCase();
                      if (trimmedValue.isEmpty) {
                        return 'Please enter your email';
                      }
                      // Basic email validation
                      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(trimmedValue)) {
                        return 'Please enter a valid email address';
                      }
                      // Check for invalid patterns
                      if (trimmedValue.contains('..') || 
                          trimmedValue.startsWith('.') || 
                          trimmedValue.endsWith('.') ||
                          trimmedValue.contains('@.') ||
                          trimmedValue.contains('.@')) {
                        return 'Invalid email format';
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
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Confirm Password input
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Role selector
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.work),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'worker',
                        child: Text('Worker'),
                      ),
                      DropdownMenuItem(
                        value: 'manager',
                        child: Text('Manager'),
                      ),
                      DropdownMenuItem(
                        value: 'boss',
                        child: Text('Boss'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value ?? 'worker';
                        if (_selectedRole != 'manager') {
                          _selectedDepartmentId = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Department selector (only for Manager)
                  if (_selectedRole == 'manager')
                    ValueListenableBuilder(
                      valueListenable: _boxService.departmentsListenable,
                      builder: (context, Box<Department> box, _) {
                        final departments = box.values.toList();
                        return DropdownButtonFormField<String>(
                          value: _selectedDepartmentId,
                          decoration: const InputDecoration(
                            labelText: 'Department',
                            prefixIcon: Icon(Icons.business),
                            border: OutlineInputBorder(),
                            helperText: 'Select department for Manager role',
                          ),
                          items: departments.map((dept) {
                            return DropdownMenuItem(
                              value: dept.id,
                              child: Text(dept.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDepartmentId = value;
                            });
                          },
                          validator: (value) {
                            if (_selectedRole == 'manager' && value == null) {
                              return 'Please select a department';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Sign up button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign Up'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? '),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                          );
                        },
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

