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

  // Controllers for user creation form
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _selectedRole;

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
        _showMessage('Failed to load users: ${failure.message}', Colors.red);
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
        _showMessage('Failed to update role: ${failure.message}', Colors.red);
      },
      (updatedUser) {
        setState(() {
          _isLoading = false;
          _roleChanges.remove(userId); // Clear from pending changes
        });
        _showMessage('Role updated successfully', Colors.green);
        // Reload users to get updated data
        _loadUsers();
      },
    );
  }

  /// Create a new user with role
  Future<void> _createNewUser() async {
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _nameController.text.isEmpty || 
        _selectedRole == null) {
      _showMessage('Iltimos, barcha maydonlarni to\'ldiring', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _userRepository.createUserByAdmin(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      role: _selectedRole!,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      result.fold(
        (failure) {
          _showMessage('Foydalanuvchi yaratishda xatolik: ${failure.message}', Colors.red);
        },
        (user) {
          _showMessage('Foydalanuvchi muvaffaqiyatli yaratildi', Colors.green);
          _resetForm();
          _loadUsers();
        },
      );
    }
  }

  /// Reset form controllers
  void _resetForm() {
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();
    _selectedRole = null;
  }

  /// Role selection dropdown
  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: const InputDecoration(
        labelText: 'Rol tanlang',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person_add),
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
        DropdownMenuItem(
          value: 'courier',
          child: Text('Courier/Delivery'),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedRole = value;
        });
      },
    );
  }

  /// Show create worker dialog
  /// WHY: Allow admin to create new workers with detailed info
  void _showCreateWorkerDialog() {
    if (!_canManageUsers) {
      _showMessage('Access denied: Only managers and boss can create workers', Colors.red);
      return;
    }

    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final positionController = TextEditingController();
    String selectedRole = 'worker';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Worker'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name*',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email*',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: positionController,
                  decoration: const InputDecoration(
                    labelText: 'Position/Lavozim*',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                    hintText: 'e.g., Sotuvchi, Omborchi, Kassir',
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
                    labelText: 'System Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.admin_panel_settings),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'worker', child: Text('Worker (Read-only)')),
                    DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                    DropdownMenuItem(value: 'warehouse', child: Text('Warehouse')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'boss', child: Text('Boss')),
                    DropdownMenuItem(value: 'courier', child: Text('Courier/Delivery')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedRole = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  '* Required fields',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
                // Validation
                if (nameController.text.trim().isEmpty) {
                  _showMessage('Please enter full name', Colors.red);
                  return;
                }
                if (emailController.text.trim().isEmpty) {
                  _showMessage('Please enter email', Colors.red);
                  return;
                }
                if (positionController.text.trim().isEmpty) {
                  _showMessage('Please enter position', Colors.red);
                  return;
                }
                if (!emailController.text.contains('@')) {
                  _showMessage('Please enter valid email', Colors.red);
                  return;
                }

                Navigator.pop(context);

                if (!mounted) return;
                setState(() {
                  _isLoading = true;
                });

                // Validate inputs
                if (nameController.text.trim().isEmpty) {
                  _showMessage('Please enter worker name', Colors.red);
                  return;
                }
                if (emailController.text.trim().isEmpty) {
                  _showMessage('Please enter email', Colors.red);
                  return;
                }
                if (positionController.text.trim().isEmpty) {
                  _showMessage('Please enter position', Colors.red);
                  return;
                }
                
                Navigator.pop(context);
                
                if (!mounted) return;
                setState(() {
                  _isLoading = true;
                });
                
                // Call repository to create worker
                final result = await _userRepository.createUserByAdmin(
                  email: emailController.text.trim(),
                  password: 'TempPass123!', // Temporary password
                  name: nameController.text.trim(),
                  role: selectedRole,
                );
                
                if (!mounted) return;
                
                result.fold(
                  (failure) {
                    setState(() {
                      _isLoading = false;
                    });
                    _showMessage('Failed to create worker: ${failure.message}', Colors.red);
                  },
                  (createdUser) {
                    setState(() {
                      _isLoading = false;
                    });
                    _showMessage('Worker created successfully! Temporary password: TempPass123!', Colors.green);
                    _loadUsers();
                  },
                );
              },
              child: const Text('Create Worker'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show snackbar message
  /// WHY: Centralized error/success message display
  void _showMessage(String message, Color color) {
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
                                        if (user.position != null && user.position!.isNotEmpty)
                                          Text('Position: ${user.position}'),
                                        if (user.phone != null && user.phone!.isNotEmpty)
                                          Text('Phone: ${user.phone}'),
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
                                                value: 'cashier',
                                                child: Text('Cashier'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'warehouse',
                                                child: Text('Warehouse'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'manager',
                                                child: Text('Manager'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'boss',
                                                child: Text('Boss'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'courier',
                                                child: Text('Courier/Delivery'),
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
              onPressed: _showCreateWorkerDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Worker'),
            )
          : null,
    );
  }
}




