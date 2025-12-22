/// DepartmentsPage - Bo'limlarni boshqarish sahifasi
/// 
/// Bu sahifa quyidagi funksiyalarni ta'minlaydi:
/// - Bo'limlarni qo'shish, tahrirlash, o'chirish
/// - Bo'limlarga qismlar biriktirish
/// - Qidiruv va tartiblash
/// - Real-time yangilanishlar
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../../data/models/department_model.dart';
import '../../data/services/hive_box_service.dart';
import '../../data/services/department_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/auth_state_service.dart';
import '../../domain/repositories/department_repository.dart';
import '../../domain/entities/department.dart' as domain;
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/entities/product.dart' as domain_product;
import '../widgets/search_bar_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/animated_list_item.dart';
import '../../core/services/error_handler_service.dart';
import 'department_details_page.dart';
import 'analytics_page.dart';
import '../../l10n/app_localizations.dart';

class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({super.key});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  // Repository
  final DepartmentRepository _departmentRepository = ServiceLocator.instance.departmentRepository;
  
  // Services (for backward compatibility)
  final HiveBoxService _boxService = HiveBoxService();
  final DepartmentService _departmentService = DepartmentService();
  
  /// Check if current user can create departments
  bool get _canCreateDepartments {
    final user = AuthStateService().currentUser;
    return user != null && (user.isManager || user.isBoss);
  }
  
  /// Check if current user can edit departments
  bool get _canEditDepartments {
    final user = AuthStateService().currentUser;
    return user != null && (user.isManager || user.isBoss);
  }
  
  /// Check if current user can delete departments
  bool get _canDeleteDepartments {
    final user = AuthStateService().currentUser;
    return user != null && user.isBoss;
  }

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // State
  SortOption? _selectedSortOption;
  
  // State for initial load only
  bool _isInitialLoading = true;
  
  // FIX: Duplicate name validation
  String? _nameValidationError;
  String? _editNameValidationError; // Separate for edit dialog

  // FIX: Listener funksiyasini saqlash - dispose da olib tashlash uchun
  late final VoidCallback _searchListener;
  Timer? _searchDebounceTimer; // Debounce timer

  @override
  void initState() {
    super.initState();
    _searchListener = () {
      // Debounce: 300ms kutish
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {});
        }
      });
    };
    _searchController.addListener(_searchListener);
    
    // Real-time duplicate name validation will be handled in StreamBuilder
    
    // Initial load - after first stream event, hide loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isInitialLoading = false;
          });
        }
      });
    });
  }
  
  /// Validate department name for duplicates (case-insensitive, trimmed)
  /// NOTE: This will be called from StreamBuilder context with departments list
  void _validateDepartmentName(List<domain.Department> departments) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameValidationError = null;
        _editNameValidationError = null;
      });
      return;
    }
    
    // Check for duplicate in provided departments
    final normalizedName = name.toLowerCase();
    final hasDuplicate = departments.any((dept) {
      return dept.name.trim().toLowerCase() == normalizedName;
    });
    
    setState(() {
      _nameValidationError = hasDuplicate 
          ? 'A department with this name already exists'
          : null;
      _editNameValidationError = hasDuplicate 
          ? 'A department with this name already exists'
          : null;
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_searchListener);
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Filtrlangan va tartiblangan departmentlarni olish
  /// Repository pattern - works for both web and mobile
  List<domain.Department> _getFilteredDepartments(List<domain.Department> departments) {
    // Start with provided departments

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      departments = departments.where((dept) {
        return dept.name.toLowerCase().contains(query);
      }).toList();
    }

    // Sort
    if (_selectedSortOption != null) {
      departments.sort((a, b) {
        final ascending = _selectedSortOption!.ascending;
        switch (_selectedSortOption!) {
          case SortOption.nameAsc:
          case SortOption.nameDesc:
            return ascending 
                ? a.name.compareTo(b.name)
                : b.name.compareTo(a.name);
          default:
            return 0;
        }
      });
    }

    return departments;
  }
  
  /// Convert domain Department to Department model (for backward compatibility)
  Department _domainToModel(domain.Department domainDepartment) {
    return Department(
      id: domainDepartment.id,
      name: domainDepartment.name,
      productIds: [], // Will be loaded separately if needed
      productParts: {},
    );
  }

  /// Yangi bo'lim qo'shish
  /// Repository pattern - works for both web and mobile
  Future<void> _addDepartment() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar(AppLocalizations.of(context)?.translate('enterProductName')?.replaceAll('product', 'department') ?? 'Please enter a department name', Colors.red);
      return;
    }

    final domainDepartment = domain.Department(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      createdAt: DateTime.now(),
    );

    // Use repository to create department
    final result = await _departmentRepository.createDepartment(domainDepartment);
    
    if (mounted) {
      result.fold(
        (failure) {
          // Check if it's a duplicate name error (check error message)
          if (failure.message.toLowerCase().contains('duplicate') || 
              failure.message.toLowerCase().contains('already exists')) {
            setState(() {
              _nameValidationError = 'A department with this name already exists';
            });
          }
          _showSnackBar('Failed to add department: ${failure.message}', Colors.red);
        },
        (createdDepartment) {
          _nameController.clear();
          _nameValidationError = null;
          Navigator.pop(context);
          _showSnackBar(AppLocalizations.of(context)?.translate('productAdded')?.replaceAll('product', 'department') ?? 'Department added successfully', Colors.green);
        },
      );
    }
  }

  /// Bo'limni o'chirish
  /// Repository pattern - works for both web and mobile
  Future<void> _deleteDepartment(domain.Department department) async {
    // Use repository to delete department
    final result = await _departmentRepository.deleteDepartment(department.id);
    
    if (mounted) {
      result.fold(
        (failure) {
          _showSnackBar('Failed to delete department: ${failure.message}', Colors.red);
        },
        (_) {
          _showSnackBar(AppLocalizations.of(context)?.translate('departmentDeleted') ?? 'Department deleted', Colors.orange);
        },
      );
    }
  }

  /// Bo'limni tahrirlash
  /// Repository pattern - works for both web and mobile
  Future<void> _editDepartment(domain.Department department) async {
    _nameController.text = department.name;
    _editNameValidationError = null;

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.translate('editDepartment') ?? 'Edit Department'),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Department Name',
            border: const OutlineInputBorder(),
            errorText: _editNameValidationError,
            errorMaxLines: 2,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _nameController.clear();
              _editNameValidationError = null;
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: (_editNameValidationError != null) ? null : () async {
              if (_nameController.text.trim().isEmpty) {
                _showSnackBar(AppLocalizations.of(context)?.translate('enterProductName')?.replaceAll('product', 'department') ?? 'Please enter a department name', Colors.red);
                return;
              }
              
              // Validation will be handled by repository error message
              
              final updatedDepartment = department.copyWith(
                name: _nameController.text.trim(),
              );
              
              // Use repository to update department
              final result = await _departmentRepository.updateDepartment(updatedDepartment);
              
              if (mounted) {
                result.fold(
                  (failure) {
                    _showSnackBar('Failed to update department: ${failure.message}', Colors.red);
                  },
                  (updated) {
                    _nameController.clear();
                    _editNameValidationError = null;
                    Navigator.pop(context);
                    _showSnackBar(AppLocalizations.of(context)?.translate('departmentUpdated') ?? 'Department updated', Colors.green);
                  },
                );
              }
            },
            child: Text(AppLocalizations.of(context)?.translate('save') ?? 'Save'),
          ),
        ],
      ),
    );
  }

  /// SnackBar ko'rsatish
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Either<Failure, List<domain.Department>>>(
      stream: _departmentRepository.watchDepartments(),
      builder: (context, snapshot) {
        // Handle loading state
        if (_isInitialLoading && !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)?.translate('departments') ?? 'Departments'),
              elevation: 2,
              actions: [
                // Analytics button
                IconButton(
                  icon: const Icon(Icons.analytics),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AnalyticsPage()),
                    );
                  },
                  tooltip: 'Analytics',
                ),
              ],
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        
        // Handle error state
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)?.translate('departments') ?? 'Departments'),
              elevation: 2,
              actions: [
                // Analytics button
                IconButton(
                  icon: const Icon(Icons.analytics),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AnalyticsPage()),
                    );
                  },
                  tooltip: 'Analytics',
                ),
              ],
            ),
            body: ErrorDisplayWidget(
              error: snapshot.error,
              onRetry: () => setState(() => _isInitialLoading = true),
            ),
          );
        }
        
        // Handle data
        final departments = snapshot.data?.fold(
          (failure) {
            // Show user-friendly error message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final message = ErrorHandlerService.instance.getErrorMessage(failure);
                ErrorHandlerService.instance.showErrorSnackBar(context, message);
              }
            });
            return <domain.Department>[];
          },
          (departments) => departments,
        ) ?? <domain.Department>[];
        
        // Update validation when departments change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _nameController.text.isNotEmpty) {
            _validateDepartmentName(departments);
          }
        });
        
        final filteredDepartments = _getFilteredDepartments(departments);
        
        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)?.translate('departments') ?? 'Departments'),
            elevation: 2,
            actions: [
              // Analytics button
              IconButton(
                icon: const Icon(Icons.analytics),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AnalyticsPage()),
                  );
                },
                tooltip: 'Analytics',
              ),
            ],
          ),
          body: Column(
            children: [
              // Search va Sort section
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    SearchBarWidget(
                      controller: _searchController,
                      hintText: AppLocalizations.of(context)?.translate('searchDepartments') ?? 'Search departments...',
                      onChanged: (_) => setState(() {}),
                      onClear: () => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    SortDropdownWidget(
                      selectedOption: _selectedSortOption,
                      onChanged: (option) {
                        setState(() {
                          _selectedSortOption = option;
                        });
                      },
                      options: const [
                        SortOption.nameAsc,
                        SortOption.nameDesc,
                      ],
                    ),
                  ],
                ),
              ),

              // Departments list
              Expanded(
                child: Builder(
                  builder: (context) {

                    if (filteredDepartments.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(() => _isInitialLoading = true);
                          await Future.delayed(const Duration(milliseconds: 500));
                          setState(() => _isInitialLoading = false);
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: EmptyStateWidget(
                              icon: Icons.business,
                              title: departments.isEmpty 
                                  ? 'No departments yet' 
                                  : 'No departments match your search',
                              subtitle: departments.isEmpty
                                  ? 'Tap the + button to add a department'
                                  : 'Try adjusting your search',
                            ),
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() => _isInitialLoading = true);
                        await Future.delayed(const Duration(milliseconds: 500));
                        setState(() => _isInitialLoading = false);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: filteredDepartments.length,
                        itemBuilder: (context, index) {
                        final domainDepartment = filteredDepartments[index];
                    final department = _domainToModel(domainDepartment);

                    return AnimatedListItem(
                      delay: index * 50,
                      child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      elevation: 2,
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.business),
                        ),
                        title: Text(
                          department.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: StreamBuilder<Either<Failure, List<domain_product.Product>>>(
                          stream: ServiceLocator.instance.productRepository.watchProducts(),
                          builder: (context, snapshot) {
                            final products = snapshot.data?.fold(
                              (failure) => <domain_product.Product>[],
                              (products) => products.where((p) => p.departmentId == domainDepartment.id).toList(),
                            ) ?? <domain_product.Product>[];
                            
                            return Text('${AppLocalizations.of(context)?.translate('products') ?? 'Products'}: ${products.length}');
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DepartmentDetailsPage(
                                department: department,
                              ),
                            ),
                          );
                        },
                        trailing: (_canEditDepartments || _canDeleteDepartments)
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editDepartment(domainDepartment);
                                  } else if (value == 'delete') {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(AppLocalizations.of(context)?.translate('deleteDepartment') ?? 'Delete Department'),
                                        content: Text(
                                          '${AppLocalizations.of(context)?.translate('deleteDepartmentConfirm') ?? 'Are you sure you want to delete this department'}?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deleteDepartment(domainDepartment);
                                            },
                                            child: Text(
                                              AppLocalizations.of(context)?.translate('delete') ?? 'Delete',
                                              style: const TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (_canEditDepartments)
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit, size: 20, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Text(AppLocalizations.of(context)?.translate('edit') ?? 'Edit'),
                                        ],
                                      ),
                                    ),
                                  if (_canDeleteDepartments)
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete, size: 20, color: Colors.red),
                                          const SizedBox(width: 8),
                                          Text(AppLocalizations.of(context)?.translate('delete') ?? 'Delete'),
                                        ],
                                      ),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    ),
                    );
                  },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _canCreateDepartments
          ? FloatingActionButton(
              heroTag: "add_department_fab", // FIX: Unique hero tag
              onPressed: () {
          _nameController.clear();
          _nameValidationError = null;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context)?.translate('addDepartment') ?? 'Add New Department'),
              content: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.translate('departmentName') ?? 'Department Name',
                  border: const OutlineInputBorder(),
                  hintText: AppLocalizations.of(context)?.translate('enterDepartmentName') ?? 'Enter department name',
                  errorText: _nameValidationError,
                  errorMaxLines: 2,
                ),
                autofocus: true,
                onSubmitted: (_) {
                  if (_nameValidationError == null) {
                    _addDepartment();
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _nameController.clear();
                    _nameValidationError = null;
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
                ),
                TextButton(
                  onPressed: (_nameValidationError != null) ? null : _addDepartment,
                  child: Text(AppLocalizations.of(context)?.translate('add') ?? 'Add'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      )
          : null, // Hide button if user can't create departments
        );
      },
    );
  }
}
