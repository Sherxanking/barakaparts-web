/// Admin Panel Page - User management with role-based access control
/// 
/// WHY: Provides admin interface for managing users and their roles
/// RBAC: Only managers and boss can access this page and edit users

import 'package:flutter/material.dart';
import '../../domain/entities/user.dart' as domain;
import '../../domain/repositories/user_repository.dart';
import '../../infrastructure/datasources/supabase_user_datasource.dart';
import '../../infrastructure/repositories/user_repository_impl.dart';
import '../../core/services/auth_state_service.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final UserRepository _userRepository = UserRepositoryImpl(
    datasource: SupabaseUserDatasource(),
  );

  List<domain.User> _users = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _roleChanges = {}; // userId -> newRole

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadUsers();
  }

  /// Check if current user has admin permissions
  /// WHY: Only managers and boss can access admin panel
  bool get _canManageUsers {
    final user = AuthStateService().currentUser;
    return user != null && (user.isManager || user.isBoss);
  }

  /// Check permissions and load users
  /// WHY: Verify user has permission before loading data
  Future<void> _checkPermissionsAndLoadUsers() async {
    if (!_canManageUsers) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Access denied: Only managers and boss can access admin panel';
        _isLoading = false;
      });
      return;
    }

    await _loadUsers();
  }

  /// Load all users from Supabase
  /// WHY: Fetch users list for admin panel
  Future<void> _loadUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _userRepository.getAllUsers();

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
        _showSnackBar('Failed to load users: ${failure.message}', Colors.red);
      },
      (users) {
        setState(() {
          _isLoading = false;
          _users = users;
          _roleChanges.clear(); // Clear pending changes
        });
      },
    );
  }

  /// Update user role
  /// WHY: Allow admin to change user roles
  Future<void> _updateUserRole(String userId, String newRole) async {
    if (!mounted || !_canManageUsers) return;

    setState(() {
      _isLoading = true;
    });

    final result = await _userRepository.updateUserRole(
      userId: userId,
      newRole: newRole,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Failed to update role: ${failure.message}', Colors.red);
      },
      (updatedUser) {
        setState(() {
          _isLoading = false;
          _roleChanges.remove(userId); // Clear from pending changes
        });
        _showSnackBar('Role updated successfully', Colors.green);
        // Reload users to get updated data
        _loadUsers();
      },
    );
  }

  /// Show create user dialog
  /// WHY: Allow admin to create new users
  void _showCreateUserDialog() {
    if (!_canManageUsers) {
      _showSnackBar('Access denied: Only managers and boss can create users', Colors.red);
      return;
    }

    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRole = 'worker';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.admin_panel_settings),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'worker', child: Text('Worker')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'boss', child: Text('Boss')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedRole = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.trim().isEmpty) {
                  _showSnackBar('Please enter email', Colors.red);
                  return;
                }
                if (passwordController.text.isEmpty) {
                  _showSnackBar('Please enter password', Colors.red);
                  return;
                }
                if (nameController.text.trim().isEmpty) {
                  _showSnackBar('Please enter name', Colors.red);
                  return;
                }

                Navigator.pop(context);

                if (!mounted) return;
                setState(() {
                  _isLoading = true;
                });

                final result = await _userRepository.createUserByAdmin(
                  email: emailController.text.trim(),
                  password: passwordController.text,
                  name: nameController.text.trim(),
                  role: selectedRole,
                );

                if (!mounted) return;

                result.fold(
                  (failure) {
                    setState(() {
                      _isLoading = false;
                    });
                    _showSnackBar('Failed to create user: ${failure.message}', Colors.red);
                  },
                  (createdUser) {
                    setState(() {
                      _isLoading = false;
                    });
                    _showSnackBar('User created successfully', Colors.green);
                    _loadUsers();
                  },
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show snackbar message
  /// WHY: Centralized error/success message display
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthStateService().currentUser;
    final canManage = _canManageUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadUsers,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _isLoading && _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _checkPermissionsAndLoadUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Current user info
                    if (currentUser != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Logged in as: ${currentUser.name}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  Text(
                                    'Role: ${currentUser.role.toUpperCase()}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Users list
                    Expanded(
                      child: _users.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No users found',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final pendingRole = _roleChanges[user.id] ?? user.role;

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      child: Text(
                                        user.name[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    title: Text(
                                      user.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Email: ${user.email ?? 'N/A'}'),
                                        const SizedBox(height: 4),
                                        if (canManage)
                                          DropdownButtonFormField<String>(
                                            value: pendingRole,
                                            decoration: const InputDecoration(
                                              labelText: 'Role',
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
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
                                            onChanged: (newRole) {
                                              if (newRole != null && newRole != user.role) {
                                                setState(() {
                                                  _roleChanges[user.id] = newRole;
                                                });
                                              } else {
                                                setState(() {
                                                  _roleChanges.remove(user.id);
                                                });
                                              }
                                            },
                                          )
                                        else
                                          Text(
                                            'Role: ${user.role.toUpperCase()}',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: canManage && _roleChanges.containsKey(user.id)
                                        ? IconButton(
                                            icon: const Icon(Icons.save),
                                            color: Colors.green,
                                            onPressed: _isLoading
                                                ? null
                                                : () => _updateUserRole(
                                                      user.id,
                                                      _roleChanges[user.id]!,
                                                    ),
                                            tooltip: 'Save role change',
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _showCreateUserDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create User'),
            )
          : null,
    );
  }
}




