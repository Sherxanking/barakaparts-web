/// ProductsPage - Mahsulotlarni boshqarish sahifasi
/// 
/// Bu sahifa quyidagi funksiyalarni ta'minlaydi:
/// - Mahsulotlarni qo'shish, tahrirlash, o'chirish
/// - Mahsulotlarga qismlar biriktirish
/// - Department bo'yicha filtrlash
/// - Qidiruv va tartiblash
/// - Real-time yangilanishlar
import 'dart:async' show StreamSubscription, TimeoutException, Timer;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/product_model.dart';
import '../../data/models/part_model.dart';
import '../../data/models/department_model.dart';
import '../../data/services/hive_box_service.dart';
import '../../data/services/product_service.dart';
import '../../data/services/department_service.dart';
import '../../data/services/part_service.dart';
import '../../core/di/service_locator.dart';
import '../../domain/entities/product.dart' as domain;
import '../../domain/entities/part.dart' as domain;
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/part_repository.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/filter_chip_widget.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/parts_list_widget.dart';
import '../../core/services/error_handler_service.dart';
import 'product_edit_page.dart';
import 'product_sales_page.dart';
import 'analytics_page.dart';
import '../../core/services/auth_state_service.dart';
import '../../data/services/excel_import_service.dart';
import '../../l10n/app_localizations.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // Repository
  final ProductRepository _productRepository = ServiceLocator.instance.productRepository;
  final PartRepository _partRepository = ServiceLocator.instance.partRepository;
  final ExcelImportService _excelImportService = ExcelImportService();
  
  // Services (for backward compatibility - will be removed gradually)
  final HiveBoxService _boxService = HiveBoxService();
  final ProductService _productService = ProductService();
  final DepartmentService _departmentService = DepartmentService();
  final PartService _partService = PartService();
  
  // Import state
  bool _isImporting = false;
  
  /// Check if current user can create products
  bool get _canCreateProducts {
    final user = AuthStateService().currentUser;
    return user != null && (user.isManager || user.isBoss);
  }

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // State
  String? selectedDepartmentId;
  String? _selectedDepartmentFilter;
  Map<String, int> selectedParts = {};
  SortOption? _selectedSortOption;
  
  // State for initial load only
  bool _isInitialLoading = true;
  List<PartModel> _webParts = [];
  bool _isLoadingWebParts = false;
  
  // FIX: Duplicate prevention - loading state
  bool _isCreatingProduct = false;
  
  // FIX: Duplicate name validation
  String? _nameValidationError;

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
  
  /// Chrome'da partslarni yuklash (Supabase'dan)
  Future<void> _loadWebParts() async {
    if (_isLoadingWebParts) return;
    
    setState(() {
      _isLoadingWebParts = true;
    });
    
    try {
      final repository = ServiceLocator.instance.partRepository;
      final result = await repository.getAllParts();
      
      result.fold(
        (failure) {
          // Xatolik bo'lsa bo'sh ro'yxat
          if (mounted) {
            setState(() {
              _webParts = [];
              _isLoadingWebParts = false;
            });
          }
        },
        (domainParts) {
          // Domain Part'larni PartModel'ga o'tkazish
          final parts = domainParts.map((domainPart) {
            return PartModel(
              id: domainPart.id,
              name: domainPart.name,
              quantity: domainPart.quantity,
              status: 'available',
              imagePath: domainPart.imagePath,
              minQuantity: domainPart.minQuantity ?? 3,
            );
          }).toList();
          
          if (mounted) {
            setState(() {
              _webParts = parts;
              _isLoadingWebParts = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _webParts = [];
          _isLoadingWebParts = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_searchListener);
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Filtrlangan va tartiblangan productlarni olish
  /// Repository pattern - works for both web and mobile
  /// Manager uchun department filter qo'shildi
  List<domain.Product> _getFilteredProducts(List<domain.Product> products) {
    // Start with provided products
    
    // Manager uchun department filter (faqat o'z department'idagi products)
    final user = AuthStateService().currentUser;
    if (user != null && user.isManager && user.departmentId != null) {
      products = products.where((p) => p.departmentId == user.departmentId).toList();
    }

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      products = products.where((product) {
        return product.name.toLowerCase().contains(query);
      }).toList();
    }

    // Department filter
    if (_selectedDepartmentFilter != null) {
      products = products.where((p) => p.departmentId == _selectedDepartmentFilter).toList();
    }

    // Sort
    if (_selectedSortOption != null) {
      products.sort((a, b) {
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

    return products;
  }

  /// Validate product name for duplicates (case-insensitive, trimmed)
  /// NOTE: This will be called from StreamBuilder context with products list
  void _validateProductName(List<domain.Product> products) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameValidationError = null;
      });
      return;
    }
    
    // Check for duplicate in provided products
    final normalizedName = name.toLowerCase();
    final hasDuplicate = products.any((product) {
      return product.name.trim().toLowerCase() == normalizedName;
    });
    
    setState(() {
      _nameValidationError = hasDuplicate 
          ? 'A product with this name already exists'
          : null;
    });
  }

  /// Yangi mahsulot qo'shish
  /// Repository pattern - works for both web and mobile
  Future<void> _addProduct() async {
    // Prevent duplicate creation
    if (_isCreatingProduct) {
      debugPrint('⚠️ Product creation already in progress, ignoring duplicate request');
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showSnackBar(AppLocalizations.of(context)?.translate('enterProductName') ?? 'Please enter a product name', Colors.red);
      return;
    }

    if (selectedDepartmentId == null) {
      _showSnackBar(AppLocalizations.of(context)?.translate('pleaseSelectDepartment') ?? 'Please select a department', Colors.red);
      return;
    }

    if (selectedParts.isEmpty) {
      _showSnackBar(AppLocalizations.of(context)?.translate('selectAtLeastOnePart') ?? 'Please select at least one part', Colors.red);
      return;
    }

    // Set loading state
    if (mounted) {
      setState(() {
        _isCreatingProduct = true;
      });
    }

    try {
      final domainProduct = domain.Product(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        departmentId: selectedDepartmentId!,
        partsRequired: Map.from(selectedParts),
        createdAt: DateTime.now(),
      );

      // Use repository to create product
      final result = await _productRepository.createProduct(domainProduct);
      
      if (mounted) {
        result.fold(
          (failure) {
            // Check if it's a duplicate name error (check error message)
            if (failure.message.toLowerCase().contains('duplicate') || 
                failure.message.toLowerCase().contains('already exists')) {
              setState(() {
                _nameValidationError = 'A product with this name already exists';
              });
            }
            _showSnackBar('Failed to add product: ${failure.message}', Colors.red);
          },
          (createdProduct) {
            // Department productIds ni yangilash (backward compatibility)
            _departmentService.assignProductToDepartment(
              selectedDepartmentId!,
              createdProduct.id,
            ).catchError((e) {
              debugPrint('⚠️ Failed to update department: $e');
            });

            // Formni tozalash
            _nameController.clear();
            selectedDepartmentId = null;
            selectedParts.clear();
            _nameValidationError = null;

            Navigator.pop(context);
            _showSnackBar(AppLocalizations.of(context)?.translate('productAdded') ?? 'Product added successfully', Colors.green);
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error creating product: $e');
      if (mounted) {
        _showSnackBar('Unexpected error: ${e.toString()}', Colors.red);
      }
    } finally {
      // Clear loading state
      if (mounted) {
        setState(() {
          _isCreatingProduct = false;
        });
      }
    }
  }

  /// Convert domain Product to Product model (for backward compatibility)
  Product _domainToModel(domain.Product domainProduct) {
    return Product(
      id: domainProduct.id,
      name: domainProduct.name,
      departmentId: domainProduct.departmentId,
      parts: domainProduct.partsRequired,
    );
  }

  /// Mahsulotni o'chirish
  /// Repository pattern - works for both web and mobile
  Future<void> _deleteProduct(domain.Product product) async {
    if (!mounted) return;
    
    try {
      // Departmentdan olib tashlash (backward compatibility)
      _departmentService.removeProductFromDepartment(
        product.departmentId,
        product.id,
      ).catchError((e) {
        debugPrint('⚠️ Failed to remove product from department: $e');
      });
      
      // Use repository to delete product
      final result = await _productRepository.deleteProduct(product.id);
      
      if (mounted) {
        result.fold(
          (failure) {
            _showSnackBar('Failed to delete product: ${failure.message}', Colors.red);
          },
          (_) {
            _showSnackBar(AppLocalizations.of(context)?.translate('productDeleted') ?? 'Product deleted', Colors.orange);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('${AppLocalizations.of(context)?.translate('error') ?? 'Error'} deleting product: ${e.toString()}', Colors.red);
      }
    }
  }

  /// Qismlar tanlash dialogini ko'rsatish
  /// 
  /// Part quantity'ni validatsiya qilish va yangilash
  void _validateAndUpdatePartQuantity(
    String partId,
    String val,
    Map<String, TextEditingController> controllers,
    Map<String, int> tempSelectedParts,
    void Function(void Function()) setDialogState,
  ) {
    try {
      final controller = controllers[partId];
      if (controller == null) return;
      
      setDialogState(() {
        // Bo'sh bo'lsa, oldingi qiymatni saqlash
        if (val.isEmpty) {
          final prevQty = tempSelectedParts[partId];
          if (prevQty != null && prevQty > 0) {
            controller.text = prevQty.toString();
          }
          return;
        }
        
        // Faqat raqamlarni qabul qilish
        if (!RegExp(r'^\d+$').hasMatch(val)) {
          // Noto'g'ri kiritilgan qiymat, oldingi qiymatga qaytarish
          final prevQty = tempSelectedParts[partId] ?? 1;
          controller.text = prevQty.toString();
          return;
        }
        
        final newQty = int.tryParse(val);
        if (newQty != null && newQty > 0) {
          // Valid raqam kiritilganda yangilash
          tempSelectedParts[partId] = newQty;
        } else if (newQty == 0) {
          // 0 kiritilsa, part'ni olib tashlash
          tempSelectedParts.remove(partId);
          controller.text = '';
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _validateAndUpdatePartQuantity: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Bu metod yangi mahsulot yaratishda qismlar tanlash uchun dialog ko'rsatadi.
  /// Har bir qism uchun miqdor kiritish maydoni mavjud.
  Future<void> _showPartsDialog() async {
    // FIX: Chrome'da partslarni yuklash kerak bo'lsa
    if (kIsWeb && _webParts.isEmpty && !_isLoadingWebParts) {
      await _loadWebParts();
    }
    
    // FIX: Chrome'da partslar yuklanayotgan bo'lsa, kutish
    if (kIsWeb && _isLoadingWebParts) {
      // Loading dialog ko'rsatish
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        );
      }
      
      // Partslar yuklanguncha kutish
      while (_isLoadingWebParts && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (mounted) {
        Navigator.pop(context); // Loading dialog'ni yopish
      }
    }
    
    // FIX: Chrome'da state'dan olish
    final allParts = kIsWeb ? _webParts : _partService.getAllParts();
    
    if (allParts.isEmpty) {
      if (mounted) {
        _showSnackBar(AppLocalizations.of(context)?.translate('noPartsAvailable') ?? 'No parts available. Please add parts first.', Colors.orange);
      }
      return;
    }
    
    Map<String, int> tempSelectedParts = Map.from(selectedParts);
    // Har bir qism uchun miqdor kiritish maydoni controllerlari
    final Map<String, TextEditingController> controllers = {};

    // Barcha qismlar uchun controllerlarni yaratish
    for (final part in allParts) {
      final qty = tempSelectedParts[part.id] ?? 0;
      controllers[part.id] = TextEditingController(
        text: qty > 0 ? qty.toString() : '',
      );
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.translate('selectParts') ?? 'Select Parts'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: allParts.map((part) {
                  final qty = tempSelectedParts[part.id] ?? 0;
                  final controller = controllers[part.id];
                  // Checkbox checked bo'lishi uchun: qty > 0 yoki controller'da text bor
                  final isChecked = qty > 0 || (controller?.text.isNotEmpty ?? false);
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(part.name),
                      subtitle: Text('${AppLocalizations.of(context)?.translate('available') ?? 'Available'}: ${part.quantity}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Qismni tanlash checkbox
                          Checkbox(
                            value: isChecked,
                            onChanged: (value) {
                              try {
                                setDialogState(() {
                                  final controller = controllers[part.id];
                                  if (controller == null) return;
                                  
                                  if (value == true) {
                                    tempSelectedParts[part.id] = 1;
                                    if (controller.text.isEmpty || controller.text != '1') {
                                      controller.text = '1';
                                    }
                                  } else {
                                    tempSelectedParts.remove(part.id);
                                    controller.text = '';
                                  }
                                });
                              } catch (e) {
                                debugPrint('❌ Error in checkbox onChanged: $e');
                              }
                            },
                          ),
                          // Miqdor kiritish maydoni (faqat tanlangan qismlar uchun)
                          if (isChecked)
                            SizedBox(
                              width: 80,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)?.translate('quantity') ?? 'Qty',
                                  isDense: true,
                                ),
                                controller: controllers[part.id],
                                textInputAction: TextInputAction.done,
                                onChanged: (val) {
                                  // onChanged'da faqat real-time yangilash, setDialogState chaqirmaslik
                                  // Bu xatoliklarni oldini oladi va performance'ni yaxshilaydi
                                  try {
                                    // Faqat valid raqamlarni qabul qilish
                                    if (val.isNotEmpty && RegExp(r'^\d+$').hasMatch(val)) {
                                      final newQty = int.tryParse(val);
                                      if (newQty != null && newQty > 0) {
                                        // Real-time yangilash, setDialogState chaqirmaslik
                                        tempSelectedParts[part.id] = newQty;
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint('❌ Error in onChanged: $e');
                                  }
                                },
                                onSubmitted: (val) {
                                  // Enter bosilganda yoki focus yo'qotilganda
                                  _validateAndUpdatePartQuantity(part.id, val, controllers, tempSelectedParts, setDialogState);
                                },
                                onEditingComplete: () {
                                  // Focus yo'qotilganda ham validatsiya qilish
                                  final controller = controllers[part.id];
                                  if (controller != null) {
                                    _validateAndUpdatePartQuantity(part.id, controller.text, controllers, tempSelectedParts, setDialogState);
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              try {
                // Faqat 0 dan katta quantity'li part'larni saqlash
                final validParts = <String, int>{};
                
                // Barcha controllerlarni tekshirish va validatsiya qilish
                // Avval barcha ma'lumotlarni olish, keyin dialog yopish
                controllers.forEach((partId, controller) {
                  try {
                    // Controller'dan text olish
                    final text = controller.text.trim();
                    if (text.isNotEmpty) {
                      final qty = int.tryParse(text);
                      if (qty != null && qty > 0) {
                        validParts[partId] = qty;
                      }
                    } else {
                      // Bo'sh bo'lsa va tempSelectedParts'da mavjud bo'lsa, oldingi qiymatni saqlash
                      final prevQty = tempSelectedParts[partId];
                      if (prevQty != null && prevQty > 0) {
                        validParts[partId] = prevQty;
                      }
                    }
                  } catch (e) {
                    // Controller bilan ishlashda xatolik (masalan, dispose bo'lgan)
                    // tempSelectedParts'dan olish
                    debugPrint('⚠️ Error reading controller for part $partId: $e');
                    final prevQty = tempSelectedParts[partId];
                    if (prevQty != null && prevQty > 0) {
                      validParts[partId] = prevQty;
                    }
                  }
                });
                
                // Dialog yopishdan oldin state'ni yangilash
                if (mounted) {
                  setState(() {
                    selectedParts = validParts;
                  });
                }
                
                // Dialog yopish
                Navigator.pop(context);
              } catch (e, stackTrace) {
                debugPrint('❌ Error saving parts: $e');
                debugPrint('Stack trace: $stackTrace');
                // Xatolik bo'lsa ham dialog yopish
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context)?.translate('save') ?? 'Save'),
          ),
        ],
      ),
    ).then((_) {
      // Dialog yopilgandan keyin controllerlarni tozalash
      // Kechikish qo'shish - dialog to'liq yopilguncha kutish
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          for (final controller in controllers.values) {
            try {
              // TextField dan ajratish uchun avval text ni tozalash
              controller.clear();
              // Keyin dispose qilish
              controller.dispose();
            } catch (e) {
              // Controller allaqachon dispose qilingan bo'lishi mumkin
              debugPrint('⚠️ Error disposing controller: $e');
            }
          }
        }
      });
    });
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

  /// Import products from Excel file
  Future<void> _importFromExcel() async {
    // First, select department
    String? selectedDeptId;
    
    final deptResult = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Department'),
        content: ValueListenableBuilder(
          valueListenable: _boxService.departmentsListenable,
          builder: (context, Box<Department> deptBox, _) {
            final departments = deptBox.values.toList();
            if (departments.isEmpty) {
              return const Text('No departments available. Please create a department first.');
            }
            
            return DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Department',
                border: OutlineInputBorder(),
              ),
              items: departments.map((dept) {
                return DropdownMenuItem(
                  value: dept.id,
                  child: Text(dept.name),
                );
              }).toList(),
              onChanged: (value) {
                selectedDeptId = value;
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selectedDeptId),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (deptResult == null || deptResult.isEmpty) {
      return; // User cancelled or no department selected
    }

    setState(() {
      _isImporting = true;
    });

    try {
      // 1. Pick Excel file
      final fileResult = await _excelImportService.pickExcelFile();
      
      if (!mounted) return;

      fileResult.fold(
        (failure) {
          setState(() {
            _isImporting = false;
          });
          _showSnackBar('Failed to pick file: ${failure.message}', Colors.red);
        },
        (file) async {
          if (file == null) {
            // User cancelled
            setState(() {
              _isImporting = false;
            });
            return;
          }

          // 2. Parse Excel file
          final parseResult = await _excelImportService.parseProductsFromExcel(
            file,
            deptResult,
          );
          
          if (!mounted) return;

          parseResult.fold(
            (failure) {
              setState(() {
                _isImporting = false;
              });
              _showSnackBar('Failed to parse Excel: ${failure.message}', Colors.red);
            },
            (products) async {
              if (products.isEmpty) {
                setState(() {
                  _isImporting = false;
                });
                _showSnackBar('No products found in Excel file', Colors.orange);
                return;
              }

              // 3. Resolve part names to IDs
              // Get all parts from repository
              final partsResult = await _partRepository.getAllParts();
              final allParts = partsResult.fold(
                (failure) {
                  debugPrint('⚠️ Failed to load parts: ${failure.message}');
                  return <domain.Part>[];
                },
                (parts) => parts,
              );
              
              final productsWithPartIds = <domain.Product>[];

              for (final product in products) {
                final resolvedParts = <String, int>{};
                
                for (final entry in product.partsRequired.entries) {
                  final partName = entry.key;
                  final quantity = entry.value;
                  
                  // Find part by name
                  try {
                    final part = allParts.firstWhere(
                      (p) => p.name.toLowerCase() == partName.toLowerCase(),
                    );
                    resolvedParts[part.id] = quantity;
                  } catch (e) {
                    debugPrint('⚠️ Part not found: $partName');
                  }
                }

                productsWithPartIds.add(product.copyWith(
                  partsRequired: resolvedParts,
                ));
              }

              // 4. Show confirmation dialog
              final shouldImport = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Import Products'),
                  content: Text(
                    'Found ${productsWithPartIds.length} products in Excel file.\n\n'
                    'Do you want to import them?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Import'),
                    ),
                  ],
                ),
              );

              if (shouldImport != true || !mounted) {
                setState(() {
                  _isImporting = false;
                });
                return;
              }

              // 5. Import products one by one
              int successCount = 0;
              int failCount = 0;

              for (final product in productsWithPartIds) {
                final result = await _productRepository.createProduct(product);
                result.fold(
                  (failure) {
                    failCount++;
                    debugPrint('❌ Failed to import ${product.name}: ${failure.message}');
                  },
                  (created) {
                    successCount++;
                    debugPrint('✅ Imported: ${created.name}');
                    
                    // Update department (backward compatibility)
                    _departmentService.assignProductToDepartment(
                      deptResult,
                      created.id,
                    ).catchError((e) {
                      debugPrint('⚠️ Failed to update department: $e');
                    });
                  },
                );
              }

              if (!mounted) return;

              setState(() {
                _isImporting = false;
              });

              // 6. Show result
              _showSnackBar(
                'Imported: $successCount, Failed: $failCount',
                failCount == 0 ? Colors.green : Colors.orange,
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
      });
      _showSnackBar('Import error: ${e.toString()}', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Either<Failure, List<domain.Product>>>(
      stream: _productRepository.watchProducts(),
      builder: (context, snapshot) {
        // Handle loading state
        if (_isInitialLoading && !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)?.translate('products') ?? 'Products'),
              elevation: 2,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        
        // Handle error state
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)?.translate('products') ?? 'Products'),
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
        final products = snapshot.data?.fold(
          (failure) {
            // Show user-friendly error message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final message = ErrorHandlerService.instance.getErrorMessage(failure);
                ErrorHandlerService.instance.showErrorSnackBar(context, message);
              }
            });
            return <domain.Product>[];
          },
          (products) => products,
        ) ?? <domain.Product>[];
        
        // Update validation when products change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _nameController.text.isNotEmpty) {
            _validateProductName(products);
          }
        });
        
        final filteredProducts = _getFilteredProducts(products);
        
        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)?.translate('products') ?? 'Products'),
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
              // Excel Import button (only for managers and boss)
              if (_canCreateProducts)
                IconButton(
                  icon: _isImporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  tooltip: 'Import from Excel',
                  onPressed: _isImporting ? null : _importFromExcel,
                ),
            ],
          ),
          body: Column(
            children: [
              // Search, Filter va Sort section
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    SearchBarWidget(
                      controller: _searchController,
                      hintText: AppLocalizations.of(context)?.translate('searchProducts') ?? 'Search products...',
                      onChanged: (_) => setState(() {}),
                      onClear: () => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // Department filter
                    ValueListenableBuilder(
                      valueListenable: _boxService.departmentsListenable,
                      builder: (context, Box<Department> box, _) {
                        final departments = box.values.toList();
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChipWidget(
                                label: AppLocalizations.of(context)?.translate('allDepartments') ?? 'All Departments',
                                selected: _selectedDepartmentFilter == null,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedDepartmentFilter = selected ? null : _selectedDepartmentFilter;
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              ...departments.map((dept) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChipWidget(
                                    label: dept.name,
                                    selected: _selectedDepartmentFilter == dept.id,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedDepartmentFilter = selected ? dept.id : null;
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
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

              // Products list
              Expanded(
                child: Builder(
                  builder: (context) {

                    if (filteredProducts.isEmpty) {
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
                              icon: Icons.inventory,
                              title: products.isEmpty 
                                  ? 'No products yet' 
                                  : 'No products match your filters',
                              subtitle: products.isEmpty
                                  ? 'Tap the + button to add a product'
                                  : 'Try adjusting your search or filters',
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
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                        final domainProduct = filteredProducts[index];
                    final product = _domainToModel(domainProduct);
                    final department = _departmentService.getDepartmentById(product.departmentId);

                    return AnimatedListItem(
                      delay: index * 50,
                      child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      elevation: 2,
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.inventory),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: _ProductSubtitleWidget(
                          department: department,
                          parts: product.parts,
                          partService: _partService,
                        ),
                        onTap: () async {
                          // Navigate to edit page
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductEditPage(product: product),
                            ),
                          );
                          // StreamBuilder will automatically refresh
                          if (result == true && mounted) {
                            setState(() {});
                          }
                        },
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'sales') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductSalesPage(
                                    productId: domainProduct.id,
                                    productName: domainProduct.name,
                                  ),
                                ),
                              );
                            } else if (value == 'delete') {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(AppLocalizations.of(context)?.translate('deleteProduct') ?? 'Delete Product'),
                                  content: Text(
                                    '${AppLocalizations.of(context)?.translate('deleteProductConfirm') ?? 'Are you sure you want to delete this product'}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteProduct(domainProduct);
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
                            PopupMenuItem(
                              value: 'sales',
                              child: Row(
                                children: [
                                  const Icon(Icons.shopping_cart, size: 20, color: Colors.green),
                                  const SizedBox(width: 8),
                                  const Text('Sales History'),
                                ],
                              ),
                            ),
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
      floatingActionButton: _canCreateProducts
          ? FloatingActionButton(
              heroTag: "add_product_fab", // FIX: Unique hero tag
              onPressed: () {
                _nameController.clear();
                selectedDepartmentId = null;
                selectedParts.clear();
                _nameValidationError = null;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context)?.translate('addProduct') ?? 'Add New Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)?.translate('productName') ?? 'Product Name',
                        border: const OutlineInputBorder(),
                        hintText: AppLocalizations.of(context)?.translate('enterProductName') ?? 'Enter product name',
                        errorText: _nameValidationError,
                        errorMaxLines: 2,
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder(
                      valueListenable: _boxService.departmentsListenable,
                      builder: (context, Box<Department> deptBox, _) {
                        final departments = deptBox.values.toList();
                        return DropdownButtonFormField<String>(
                          value: selectedDepartmentId,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.translate('selectDepartment') ?? 'Department',
                            border: const OutlineInputBorder(),
                          ),
                          items: departments.map((dept) {
                            return DropdownMenuItem(
                              value: dept.id,
                              child: Text(dept.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedDepartmentId = value;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showPartsDialog,
                      icon: const Icon(Icons.add),
                      label: Text(
                        selectedParts.isEmpty
                            ? (AppLocalizations.of(context)?.translate('selectParts') ?? 'Select Parts')
                            : '${AppLocalizations.of(context)?.translate('parts') ?? 'Parts'} (${selectedParts.length})',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _nameController.clear();
                    selectedDepartmentId = null;
                    selectedParts.clear();
                    _nameValidationError = null;
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
                ),
                TextButton(
                  onPressed: (_isCreatingProduct || _nameValidationError != null) ? null : () {
                    _addProduct();
                  },
                  child: _isCreatingProduct
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppLocalizations.of(context)?.translate('add') ?? 'Add'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      )
          : null, // Hide button if user can't create products
        );
      },
    );
  }
}

/// Product Subtitle Widget - Ixcham parts ko'rsatish
class _ProductSubtitleWidget extends StatefulWidget {
  final Department? department;
  final Map<String, int> parts;
  final PartService partService;

  const _ProductSubtitleWidget({
    required this.department,
    required this.parts,
    required this.partService,
  });

  @override
  State<_ProductSubtitleWidget> createState() => _ProductSubtitleWidgetState();
}

class _ProductSubtitleWidgetState extends State<_ProductSubtitleWidget> {
  bool _showParts = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${AppLocalizations.of(context)?.translate('department') ?? 'Department'}: ${widget.department?.name ?? AppLocalizations.of(context)?.translate('unknown') ?? 'Unknown'}'),
        const SizedBox(height: 4),
        // Parts ko'rsatish/yashirish icon bilan
        InkWell(
          onTap: () {
            setState(() {
              _showParts = !_showParts;
            });
          },
          child: Row(
            children: [
              Icon(
                _showParts ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.build,
                size: 14,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                '${AppLocalizations.of(context)?.translate('parts') ?? 'Parts'}: ${widget.parts.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _showParts ? 'Yig\'ish' : 'Ko\'rsatish',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        if (_showParts && widget.parts.isNotEmpty) ...[
          const SizedBox(height: 8),
          PartsListWidget(
            parts: widget.parts,
            partService: widget.partService,
          ),
        ],
      ],
    );
  }
}
