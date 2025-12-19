/// DepartmentsPage - Bo'limlarni boshqarish sahifasi
/// 
/// Bu sahifa quyidagi funksiyalarni ta'minlaydi:
/// - Bo'limlarni qo'shish, tahrirlash, o'chirish
/// - Bo'limlarga qismlar biriktirish
/// - Qidiruv va tartiblash
/// - Real-time yangilanishlar
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/department_model.dart';
import '../../data/services/hive_box_service.dart';
import '../../data/services/department_service.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/animated_list_item.dart';
import 'department_details_page.dart';

class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({super.key});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  // Services
  final HiveBoxService _boxService = HiveBoxService();
  final DepartmentService _departmentService = DepartmentService();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // State
  SortOption? _selectedSortOption;
  
  // FIX: Duplicate name validation
  String? _nameValidationError;
  String? _editNameValidationError; // Separate for edit dialog

  // FIX: Listener funksiyasini saqlash - dispose da olib tashlash uchun
  late final VoidCallback _searchListener;

  @override
  void initState() {
    super.initState();
    _searchListener = () => setState(() {});
    _searchController.addListener(_searchListener);
    
    // FIX: Real-time duplicate name validation
    _nameController.addListener(_validateDepartmentName);
  }
  
  /// Validate department name for duplicates (case-insensitive, trimmed)
  void _validateDepartmentName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameValidationError = null;
        _editNameValidationError = null;
      });
      return;
    }
    
    // Check for duplicate in Hive
    final normalizedName = name.toLowerCase();
    final hasDuplicate = _departmentService.getAllDepartments().any((dept) {
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
    // FIX: Listener ni olib tashlash dispose dan oldin
    _searchController.removeListener(_searchListener);
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Filtrlangan va tartiblangan departmentlarni olish
  List<Department> _getFilteredDepartments() {
    List<Department> departments = _departmentService.searchDepartments(
      _searchController.text,
    );

    // Tartiblash
    if (_selectedSortOption != null) {
      departments = _departmentService.sortDepartments(
        departments,
        _selectedSortOption!.ascending,
      );
    }

    return departments;
  }

  /// Yangi bo'lim qo'shish
  Future<void> _addDepartment() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a department name', Colors.red);
      return;
    }

    final department = Department(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      productIds: [],
      productParts: {},
    );

    // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
    final success = await _departmentService.addDepartment(department);
    if (mounted) {
      if (success) {
        _nameController.clear();
        _nameValidationError = null;
        _showSnackBar('Department added successfully', Colors.green);
        Navigator.pop(context); // Dialog yopish
      } else {
        // Check if it's a duplicate name error
        final normalizedName = department.name.trim().toLowerCase();
        final hasDuplicate = _departmentService.getAllDepartments().any((d) {
          return d.name.trim().toLowerCase() == normalizedName;
        });
        
        if (hasDuplicate) {
          setState(() {
            _nameValidationError = 'A department with this name already exists';
          });
          // FIX: Dialog yopilgandan keyin xabar ko'rsatish
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showSnackBar('A department with this name already exists. Please use a different name.', Colors.red);
            }
          });
        } else {
          // FIX: Dialog yopilgandan keyin xabar ko'rsatish
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showSnackBar('Failed to add department. Please try again.', Colors.red);
            }
          });
        }
      }
    }
  }

  /// Bo'limni o'chirish
  Future<void> _deleteDepartment(Department department) async {
    final departments = _getFilteredDepartments();
    final index = departments.indexOf(department);
    
    if (index >= 0) {
      // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
      final success = await _departmentService.deleteDepartment(index);
      if (mounted) {
        if (success) {
          _showSnackBar('Department deleted', Colors.orange);
        } else {
          _showSnackBar('Failed to delete department. Please try again.', Colors.red);
        }
      }
    }
  }

  /// Bo'limni tahrirlash
  Future<void> _editDepartment(Department department) async {
    _nameController.text = department.name;
    _editNameValidationError = null; // Reset validation error

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Department'),
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: (_editNameValidationError != null) ? null : () async {
              if (_nameController.text.trim().isEmpty) {
                _showSnackBar('Please enter a department name', Colors.red);
                return;
              }
              
              // Check for duplicate (exclude current department)
              final normalizedName = _nameController.text.trim().toLowerCase();
              final hasDuplicate = _departmentService.getAllDepartments().any((d) {
                return d.id != department.id && d.name.trim().toLowerCase() == normalizedName;
              });
              
              if (hasDuplicate) {
                setState(() {
                  _editNameValidationError = 'A department with this name already exists';
                });
                _showSnackBar('A department with this name already exists. Please use a different name.', Colors.red);
                return;
              }
              
              department.name = _nameController.text.trim();
              // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
              final success = await _departmentService.updateDepartment(department);
              if (mounted) {
                if (success) {
                  _nameController.clear();
                  _editNameValidationError = null;
                  Navigator.pop(context);
                  _showSnackBar('Department updated', Colors.green);
                } else {
                  // Check if it's a duplicate name error
                  final normalizedName = department.name.trim().toLowerCase();
                  final hasDuplicate = _departmentService.getAllDepartments().any((d) {
                    return d.id != department.id && d.name.trim().toLowerCase() == normalizedName;
                  });
                  
                  if (hasDuplicate) {
                    setState(() {
                      _editNameValidationError = 'A department with this name already exists';
                    });
                    _showSnackBar('A department with this name already exists. Please use a different name.', Colors.red);
                  } else {
                    _showSnackBar('Failed to update department. Please try again.', Colors.red);
                  }
                }
              }
            },
            child: const Text('Save'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments'),
        elevation: 2,
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
                  hintText: 'Search departments...',
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
            child: ValueListenableBuilder(
              valueListenable: _boxService.departmentsListenable,
              builder: (context, Box<Department> box, _) {
                final departments = _getFilteredDepartments();

                if (departments.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: EmptyStateWidget(
                          icon: Icons.business,
                          title: box.isEmpty 
                              ? 'No departments yet' 
                              : 'No departments match your search',
                          subtitle: box.isEmpty
                              ? 'Tap the + button to add a department'
                              : 'Try adjusting your search',
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: departments.length,
                    itemBuilder: (context, index) {
                    final department = departments[index];

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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Products: ${department.productIds.length}'),
                            Text('Parts assigned: ${department.productParts.length}'),
                          ],
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editDepartment(department),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Department'),
                                    content: const Text(
                                      'Are you sure you want to delete this department?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteDepartment(department);
                                        },
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _nameController.clear();
          _nameValidationError = null;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Add New Department'),
              content: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Department Name',
                  border: const OutlineInputBorder(),
                  hintText: 'Enter department name',
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
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: (_nameValidationError != null) ? null : _addDepartment,
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
