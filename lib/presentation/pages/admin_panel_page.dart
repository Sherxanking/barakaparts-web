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
  final TextEditingController _searchController = TextEditingController();
  String? _selectedRole;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _checkPermissionsAndLoadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
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

  /// Get color based on role
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'boss':
        return Colors.deepPurple;
      case 'manager':
        return Colors.blue;
      case 'worker':
        return Colors.green;
      case 'courier':
        return Colors.orange;
      case 'warehouse':
        return Colors.teal;
      case 'cashier':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  /// Get icon based on role
  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'boss':
        return Icons.star;
      case 'manager':
        return Icons.admin_panel_settings;
      case 'worker':
        return Icons.engineering;
      case 'courier':
        return Icons.delivery_dining;
      case 'warehouse':
        return Icons.inventory_2;
      case 'cashier':
        return Icons.point_of_sale;
      default:
        return Icons.person;
    }
  }

  /// Get filtered users based on search query
  List<domain.User> _getFilteredUsers() {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final name = user.name.toLowerCase();
      final email = (user.email ?? '').toLowerCase();
      final pos = (user.position ?? '').toLowerCase();
      final role = user.role.toLowerCase();
      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          pos.contains(_searchQuery) ||
          role.contains(_searchQuery);
    }).toList();
  }

  /// Get stats by role
  Map<String, int> _getStats() {
    final stats = <String, int>{};
    for (var user in _users) {
      stats[user.role] = (stats[user.role] ?? 0) + 1;
    }
    return stats;
  }

  /// Role selection dropdown
  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: InputDecoration(
        labelText: 'Rol tanlang',
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.person_add),
      ),
      items: const [
        DropdownMenuItem(value: 'worker', child: Text('Worker')),
        DropdownMenuItem(value: 'manager', child: Text('Manager')),
        DropdownMenuItem(value: 'boss', child: Text('Boss')),
        DropdownMenuItem(value: 'courier', child: Text('Courier/Delivery')),
        DropdownMenuItem(value: 'warehouse', child: Text('Warehouse')),
        DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_add_rounded, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 12),
              const Text('Create New Worker', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModernTextField(
                  controller: nameController,
                  label: 'Full Name*',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: emailController,
                  label: 'Email*',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: positionController,
                  label: 'Position/Lavozim*',
                  icon: Icons.work_outline,
                  hint: 'e.g., Sotuvchi, Omborchi',
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: phoneController,
                  label: 'Phone (Optional)',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'System Role',
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'worker', child: Text('Worker')),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                // Validation
                String name = nameController.text.trim();
                String email = emailController.text.trim();
                String position = positionController.text.trim();

                if (name.isEmpty || email.isEmpty || position.isEmpty) {
                  _showMessage('Please fill all required fields', Colors.red);
                  return;
                }
                if (!email.contains('@')) {
                  _showMessage('Please enter a valid email', Colors.red);
                  return;
                }

                // Close dialog
                Navigator.pop(context);

                if (!mounted) return;
                setState(() => _isLoading = true);

                // Call repository
                final result = await _userRepository.createUserByAdmin(
                  email: email,
                  password: 'TempPass123!', 
                  name: name,
                  role: selectedRole,
                );

                if (!mounted) return;

                result.fold(
                  (failure) {
                    setState(() => _isLoading = false);
                    _showMessage('Failed to create worker: ${failure.message}', Colors.red);
                  },
                  (createdUser) {
                    setState(() => _isLoading = false);
                    _showMessage(
                      'Worker created successfully! Password: TempPass123!',
                      Colors.green,
                    );
                    _loadUsers();
                  },
                );
              },
              child: const Text('Create Worker', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1),
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
    final filteredUsers = _getFilteredUsers();
    final stats = _getStats();
    final canManage = _canManageUsers;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadUsers,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: Column(
        children: [
          // Stats Row
          if (_users.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildStatCard('Total', _users.length, Colors.blueGrey),
                  ...stats.entries.map((e) => _buildStatCard(
                        e.key.toUpperCase(),
                        e.value,
                        _getRoleColor(e.key),
                      )),
                ],
              ),
            ),

          // Search Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by name, email, role...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          Expanded(
            child: _isLoading && _users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null && _users.isEmpty
                    ? _buildErrorPlaceholder()
                    : filteredUsers.isEmpty
                        ? _buildEmptyPlaceholder()
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final pendingRole = _roleChanges[user.id] ?? user.role;
                              final roleColor = _getRoleColor(user.role);

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: ExpansionTile(
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: roleColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getRoleIcon(user.role),
                                        color: roleColor,
                                      ),
                                    ),
                                    title: Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      user.role.toUpperCase(),
                                      style: TextStyle(
                                        color: roleColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Divider(),
                                            _buildDetailItem(Icons.email_outlined, 'Email', user.email ?? 'N/A'),
                                            if (user.position != null && user.position!.isNotEmpty)
                                              _buildDetailItem(Icons.work_outline, 'Position', user.position!),
                                            if (user.phone != null && user.phone!.isNotEmpty)
                                              _buildDetailItem(Icons.phone_outlined, 'Phone', user.phone!),
                                            const SizedBox(height: 16),
                                            if (canManage) ...[
                                              const Text('Change Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: DropdownButtonFormField<String>(
                                                      value: pendingRole,
                                                      isDense: true,
                                                      decoration: InputDecoration(
                                                        isDense: true,
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                        filled: true,
                                                        fillColor: Colors.grey[50],
                                                      ),
                                                      items: const [
                                                        DropdownMenuItem(value: 'worker', child: Text('Worker')),
                                                        DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                                                        DropdownMenuItem(value: 'warehouse', child: Text('Warehouse')),
                                                        DropdownMenuItem(value: 'manager', child: Text('Manager')),
                                                        DropdownMenuItem(value: 'boss', child: Text('Boss')),
                                                        DropdownMenuItem(value: 'courier', child: Text('Courier')),
                                                      ],
                                                      onChanged: (newRole) {
                                                        if (newRole != null && newRole != user.role) {
                                                          setState(() => _roleChanges[user.id] = newRole);
                                                        } else {
                                                          setState(() => _roleChanges.remove(user.id));
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  if (_roleChanges.containsKey(user.id))
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 8),
                                                      child: IconButton.filled(
                                                        onPressed: _isLoading ? null : () => _updateUserRole(user.id, _roleChanges[user.id]!),
                                                        icon: const Icon(Icons.check_rounded, color: Colors.white),
                                                        style: IconButton.styleFrom(backgroundColor: Colors.green),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('New Worker', style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            )
          : null,
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No matching users found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          Text('Try a different search term', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 80, color: Colors.red[100]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700])),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _checkPermissionsAndLoadUsers,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}




