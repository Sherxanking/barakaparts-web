/// ProductsPage - Mahsulotlarni boshqarish sahifasi
/// 
/// Bu sahifa quyidagi funksiyalarni ta'minlaydi:
/// - Mahsulotlarni qo'shish, tahrirlash, o'chirish
/// - Mahsulotlarga qismlar biriktirish
/// - Department bo'yicha filtrlash
/// - Qidiruv va tartiblash
/// - Real-time yangilanishlar
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
import '../../core/services/auth_state_service.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/filter_chip_widget.dart';
import 'product_edit_page.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/skeletons.dart';
import '../../core/utils/reporting_utils.dart';
import 'package:flutter/services.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // Services
  final HiveBoxService _boxService = HiveBoxService();
  final ProductService _productService = ProductService();
  final DepartmentService _departmentService = DepartmentService();
  final PartService _partService = PartService();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // State
  String? selectedDepartmentId;
  String? _selectedDepartmentFilter;
  Map<String, int> selectedParts = {};
  SortOption? _selectedSortOption;
  bool _isSavingProduct = false;
  bool _isRefreshing = false;

  // FIX: Listener funksiyasini saqlash - dispose da olib tashlash uchun
  late final VoidCallback _searchListener;

  @override
  void initState() {
    super.initState();
    _searchListener = () => setState(() {});
    _searchController.addListener(_searchListener);
    // Sahifa ochilganda Supabase'dan yangilash
    Future.microtask(() => _refreshFromSupabase());
  }

  /// Supabase'dan fresh ma'lumotlarni yuklash
  Future<void> _refreshFromSupabase() async {
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);

    try {
      final productRepository = ServiceLocator.instance.productRepository;
      final result = await productRepository.getAllProducts();

      await result.fold(
        (failure) async {
          debugPrint('❌ Products refresh error: ${failure.message}');
        },
        (products) async {
          if (products.isNotEmpty) {
            final box = _boxService.productsBox;
            await box.clear();
            for (var p in products) {
              await box.add(Product(
                id: p.id,
                name: p.name,
                departmentId: p.departmentId,
                parts: p.partsRequired,
              ));
            }
            debugPrint('✅ ${products.length} ta product Supabase\'dan yangilandi');
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Unexpected error during refresh: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    // FIX: Listener ni olib tashlash dispose dan oldin
    _searchController.removeListener(_searchListener);
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Filtrlangan va tartiblangan productlarni olish
  List<Product> _getFilteredProducts() {
    List<Product> products = _productService.searchAndFilterProducts(
      query: _searchController.text.isEmpty ? null : _searchController.text,
      departmentId: _selectedDepartmentFilter,
    );

    // Tartiblash
    if (_selectedSortOption != null) {
      products = _productService.sortProducts(
        products,
        _selectedSortOption!.ascending,
      );
    }

    return products;
  }

  /// Yangi mahsulot qo'shish
  /// FIX: Batafsil debug log
  Future<void> _addProduct() async {
    if (_isSavingProduct) return;
    _isSavingProduct = true;
    
    debugPrint('🔄 Starting product creation flow...');
    debugPrint('   Product name: ${_nameController.text.trim()}');
    debugPrint('   Department ID: $selectedDepartmentId');
    debugPrint('   Parts count: ${selectedParts.length}');
    
    if (mounted) {
      setState(() {});
    }

    // Validatsiya
    if (_nameController.text.trim().isEmpty) {
      debugPrint('❌ Product name is empty');
      _showSnackBar('Please enter a product name', Colors.red);
      _isSavingProduct = false;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (selectedDepartmentId == null) {
      debugPrint('❌ No department selected');
      _showSnackBar('Please select a department', Colors.red);
      _isSavingProduct = false;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (selectedParts.isEmpty) {
      debugPrint('❌ No parts selected');
      _showSnackBar('Please select at least one part', Colors.red);
      _isSavingProduct = false;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    
    // Validate part IDs
    for (final partId in selectedParts.keys) {
      if (!_isValidUuid(partId)) {
        debugPrint('❌ Invalid part ID: $partId');
        _showSnackBar('Invalid part selected. Please try again.', Colors.red);
        _isSavingProduct = false;
        if (mounted) {
          setState(() {});
        }
        return;
      }
    }

    try {
      final product = Product(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        departmentId: selectedDepartmentId!,
        parts: Map.from(selectedParts),
      );

      debugPrint('✅ Validation passed, creating product...');
      
      // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
      final success = await _productService.addProduct(product);
      
      if (mounted) {
        if (success) {
          debugPrint('✅ Product created successfully');
          // Department productIds ni yangilash
          await _departmentService.assignProductToDepartment(
            selectedDepartmentId!,
            product.id,
          );

          // Formni tozalash
          _nameController.clear();
          selectedDepartmentId = null;
          selectedParts.clear();

          _showSnackBar('Product added successfully', Colors.green);
          Navigator.pop(context);
        } else {
          debugPrint('❌ Failed to create product');
          _showSnackBar('Failed to add product. Please try again.', Colors.red);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error in _addProduct: $e');
      debugPrint('   Stack trace: $stackTrace');
      if (mounted) {
        _showSnackBar('Unexpected error occurred. Please try again.', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProduct = false;
        });
      }
    }
  }
  
  /// Validate UUID format
  bool _isValidUuid(String uuid) {
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
    return uuidRegex.hasMatch(uuid.toLowerCase());
  }

  /// Mahsulotni o'chirish
  Future<void> _deleteProduct(Product product) async {
    // FIX: Product ID bo'yicha o'chirish - index muammosini hal qilish
    // Departmentdan olib tashlash
    await _departmentService.removeProductFromDepartment(
      product.departmentId,
      product.id,
    );
    
    // FIX: Product ID bo'yicha o'chirish (index emas)
    // Repository pattern ishlatish
    final productRepository = ServiceLocator.instance.productRepository;
    final result = await productRepository.deleteProduct(product.id);
    
    if (mounted) {
      result.fold(
        (failure) {
          _showSnackBar('Failed to delete product: ${failure.message}', Colors.red);
        },
        (_) {
          _showSnackBar('Product deleted', Colors.orange);
        },
      );
    }
  }

  /// Qismlar tanlash dialogini ko'rsatish
  /// 
  /// Bu metod yangi mahsulot yaratishda qismlar tanlash uchun dialog ko'rsatadi.
  /// Har bir qism uchun miqdor kiritish maydoni mavjud.
  void _showPartsDialog() {
    final allParts = _partService.getAllParts();
    Map<String, int> tempSelectedParts = Map.from(selectedParts);
    // Har bir qism uchun miqdor kiritish maydoni controllerlari
    final Map<String, TextEditingController> controllers = {};
    final TextEditingController searchController = TextEditingController();

    // Barcha qismlar uchun controllerlarni yaratish
    for (final part in allParts) {
      final qty = tempSelectedParts[part.id] ?? 0;
      controllers[part.id] = TextEditingController(
        text: qty > 0 ? qty.toString() : '',
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Parts'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search parts...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  ...allParts
                      .where((part) {
                        final query = searchController.text.trim().toLowerCase();
                        if (query.isEmpty) return true;
                        return part.name.toLowerCase().contains(query);
                      })
                      .map((part) {
                  final qty = tempSelectedParts[part.id] ?? 0;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(part.name),
                      subtitle: Text('Available: ${part.quantity}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Qismni tanlash checkbox
                          Checkbox(
                            value: qty > 0,
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempSelectedParts[part.id] = 1;
                                  controllers[part.id]!.text = '1';
                                } else {
                                  tempSelectedParts.remove(part.id);
                                  controllers[part.id]!.text = '';
                                }
                              });
                            },
                          ),
                          // Miqdor kiritish maydoni (faqat tanlangan qismlar uchun)
                          if (qty > 0)
                            SizedBox(
                              width: 80,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                  isDense: true,
                                ),
                                controller: controllers[part.id],
                                onChanged: (val) {
                                  final newQty = int.tryParse(val);
                                  if (newQty != null && newQty > 0) {
                                    tempSelectedParts[part.id] = newQty;
                                  } else if (val.isEmpty) {
                                    // Yozish paytida bo'sh qoldirishga ruxsat berish
                                  } else {
                                    // Noto'g'ri kiritilgan qiymat, oldingi qiymatga qaytarish
                                    final prevQty = tempSelectedParts[part.id] ?? 1;
                                    controllers[part.id]!.text = prevQty.toString();
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              selectedParts = tempSelectedParts;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      // Dialog yopilgandan keyin controllerlarni tozalash
      if (mounted) {
        searchController.dispose();
        for (final controller in controllers.values) {
          try {
            controller.dispose();
          } catch (e) {
            // Controller allaqachon dispose qilingan bo'lishi mumkin
          }
        }
      }
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

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthStateService().currentUser;
    final canCreateProducts = currentUser != null && (currentUser.isManager || currentUser.isBoss);
    final canEditProducts = currentUser != null && (currentUser.isManager || currentUser.isBoss);
    final canDeleteProducts = currentUser != null && currentUser.isBoss;

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ValueListenableBuilder(
        valueListenable: _boxService.productsListenable,
        builder: (context, Box<Product> box, _) {
          final products = _getFilteredProducts();
          final totalProducts = box.length;
          final filteredCount = products.length;

          return RefreshIndicator(
            onRefresh: () async {
              await _refreshFromSupabase();
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  floating: true,
                  pinned: true,
                  stretch: true,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      l10n?.translate('products') ?? 'Products',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    centerTitle: false,
                    titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  ),
                  actions: [
                    if (_isRefreshing)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _refreshFromSupabase,
                      ),
                    PopupMenuButton<SortOption>(
                      icon: const Icon(Icons.sort),
                      onSelected: (option) => setState(() => _selectedSortOption = option),
                      itemBuilder: (context) => [
                        SortOption.nameAsc,
                        SortOption.nameDesc,
                      ].map((option) => PopupMenuItem(
                        value: option,
                        child: Text(option.getLabel(context)),
                      )).toList(),
                    ),
                  ],
                ),

                // Search and Filters
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SearchBarWidget(
                          controller: _searchController,
                          hintText: l10n?.translate('searchProducts') ?? 'Search products...',
                          onChanged: (_) => setState(() {}),
                          onClear: () => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        _buildDepartmentFilter(),
                      ],
                    ),
                  ),
                ),

                // Stats Dashboard
                SliverToBoxAdapter(
                  child: _buildProductDashboard(totalProducts, filteredCount),
                ),

                // Loading State
                if (_isRefreshing && products.isEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const ProductSkeleton(),
                      childCount: 5,
                    ),
                  )
                else if (products.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateWidget(
                      icon: Icons.inventory_2_outlined,
                      title: box.isEmpty 
                          ? (l10n?.translate('noProducts') ?? 'No products yet')
                          : (l10n?.translate('noResults') ?? 'No results found'),
                      subtitle: (l10n?.translate('tryAdjustingFilters') ?? 'Try adjusting search or filters'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = products[index];
                          return _buildModernProductCard(product, canEditProducts, canDeleteProducts);
                        },
                        childCount: products.length,
                      ),
                    ),
                  ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: canCreateProducts
          ? FloatingActionButton.extended(
              onPressed: _showAddProductDialog,
              icon: const Icon(Icons.add),
              label: Text(l10n?.translate('add') ?? 'Add'),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildDepartmentFilter() {
    return ValueListenableBuilder(
      valueListenable: _boxService.departmentsListenable,
      builder: (context, Box<Department> box, _) {
        final departments = box.values.toList();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip(
                label: 'All',
                selected: _selectedDepartmentFilter == null,
                onTap: () => setState(() => _selectedDepartmentFilter = null),
              ),
              ...departments.map((dept) => _buildFilterChip(
                label: dept.name,
                selected: _selectedDepartmentFilter == dept.id,
                onTap: () => setState(() => _selectedDepartmentFilter = dept.id),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({required String label, required bool selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.blue[100],
        labelStyle: TextStyle(
          color: selected ? Colors.blue[800] : Colors.grey[700],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? Colors.blue[300]! : Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildProductDashboard(int total, int filtered) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildSmallStatCard('Total', total.toString(), Icons.inventory_2_outlined, Colors.blue),
          const SizedBox(width: 12),
          _buildSmallStatCard('Shown', filtered.toString(), Icons.filter_list, Colors.teal),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernProductCard(Product product, bool canEdit, bool canDelete) {
    final department = _departmentService.getDepartmentById(product.departmentId);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canEdit ? () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProductEditPage(product: product)),
            );
            if (result == true) setState(() {});
          } : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2, color: Colors.blue[700]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        department?.name ?? 'Unknown Department',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.settings_input_component, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            '${product.parts.length} parts',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _confirmDeleteProduct(product),
                  ),
                Icon(Icons.chevron_right, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(product);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    _nameController.clear();
    selectedDepartmentId = null;
    selectedParts.clear();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('New Product'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder(
                    valueListenable: _boxService.departmentsListenable,
                    builder: (context, Box<Department> deptBox, _) {
                      final departments = deptBox.values.toList();
                      return DropdownButtonFormField<String>(
                        value: selectedDepartmentId,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        items: departments.map((dept) => DropdownMenuItem(value: dept.id, child: Text(dept.name))).toList(),
                        onChanged: (val) => setDialogState(() => selectedDepartmentId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[300]!)),
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text(selectedParts.isEmpty ? 'Select Parts' : 'Parts (${selectedParts.length})'),
                    onTap: () async {
                      _showPartsDialog();
                      // Simple delay to update dialog state after parts selection
                      await Future.delayed(const Duration(milliseconds: 500));
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: _isSavingProduct ? null : _addProduct,
                child: _isSavingProduct ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add'),
              ),
            ],
          );
        }
      ),
    );
  }
}
