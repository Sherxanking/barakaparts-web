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
import '../widgets/search_bar_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/filter_chip_widget.dart';
import '../widgets/animated_list_item.dart';
import 'product_edit_page.dart';

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

  // FIX: Listener funksiyasini saqlash - dispose da olib tashlash uchun
  late final VoidCallback _searchListener;

  @override
  void initState() {
    super.initState();
    _searchListener = () => setState(() {});
    _searchController.addListener(_searchListener);
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
  Future<void> _addProduct() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a product name', Colors.red);
      return;
    }

    if (selectedDepartmentId == null) {
      _showSnackBar('Please select a department', Colors.red);
      return;
    }

    if (selectedParts.isEmpty) {
      _showSnackBar('Please select at least one part', Colors.red);
      return;
    }

    final product = Product(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      departmentId: selectedDepartmentId!,
      parts: Map.from(selectedParts),
    );

    // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
    final success = await _productService.addProduct(product);
    if (mounted) {
      if (success) {
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
        _showSnackBar('Failed to add product. Please try again.', Colors.red);
      }
    }
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
                children: allParts.map((part) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        elevation: 2,
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
                  hintText: 'Search products...',
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
                            label: 'All Departments',
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
            child: ValueListenableBuilder(
              valueListenable: _boxService.productsListenable,
              builder: (context, Box<Product> box, _) {
                final products = _getFilteredProducts();

                if (products.isEmpty) {
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
                          icon: Icons.inventory,
                          title: box.isEmpty 
                              ? 'No products yet' 
                              : 'No products match your filters',
                          subtitle: box.isEmpty
                              ? 'Tap the + button to add a product'
                              : 'Try adjusting your search or filters',
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
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                    final product = products[index];
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Department: ${department?.name ?? 'Unknown'}'),
                            Text('Parts: ${product.parts.length}'),
                            if (product.parts.isNotEmpty)
                              Text(
                                product.parts.entries
                                    .map((e) {
                                      final part = _partService.getPartById(e.key);
                                      return '${part?.name ?? e.key}: ${e.value}';
                                    })
                                    .join(', '),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        onTap: () async {
                          // Navigate to edit page
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductEditPage(product: product),
                            ),
                          );
                          // Refresh if product was updated
                          if (result == true) {
                            setState(() {});
                          }
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Product'),
                                content: const Text(
                                  'Are you sure you want to delete this product?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteProduct(product);
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
          selectedDepartmentId = null;
          selectedParts.clear();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Add New Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(),
                        hintText: 'Enter product name',
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
                            ? 'Select Parts'
                            : 'Parts (${selectedParts.length})',
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
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    _addProduct();
                  },
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
