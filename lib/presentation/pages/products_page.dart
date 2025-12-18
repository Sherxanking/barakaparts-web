/// ProductsPage - Mahsulotlarni boshqarish sahifasi
/// 
/// Bu sahifa quyidagi funksiyalarni ta'minlaydi:
/// - Mahsulotlarni qo'shish, tahrirlash, o'chirish
/// - Mahsulotlarga qismlar biriktirish
/// - Department bo'yicha filtrlash
/// - Qidiruv va tartiblash
/// - Real-time yangilanishlar
import 'dart:async' show StreamSubscription, TimeoutException;
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
  
  // Chrome uchun state
  List<Product> _webProducts = [];
  bool _isLoadingWebProducts = false;
  List<PartModel> _webParts = [];
  bool _isLoadingWebParts = false;
  
  // FIX: Duplicate prevention - loading state
  bool _isCreatingProduct = false;
  
  // Chrome uchun real-time stream subscription
  StreamSubscription? _productsStreamSubscription;

  // FIX: Listener funksiyasini saqlash - dispose da olib tashlash uchun
  late final VoidCallback _searchListener;

  @override
  void initState() {
    super.initState();
    _searchListener = () => setState(() {});
    _searchController.addListener(_searchListener);
    
    debugPrint('🚀 ProductsPage initState: kIsWeb = $kIsWeb');
    
    // FIX: Chrome'da productslarni yuklash
    if (kIsWeb) {
      debugPrint('   Chrome detected, loading products...');
      // PostFrameCallback orqali yuklash - UI render bo'lgandan keyin
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && kIsWeb) {
          try {
            _loadWebProducts();
            _listenToProductsStream();
          } catch (e) {
            debugPrint('❌ Error initializing web products: $e');
          }
        }
      });
    } else {
      debugPrint('   Not Chrome, skipping web-specific loading');
    }
  }
  
  /// Chrome'da products stream'ga quloq solish (real-time updates)
  void _listenToProductsStream() {
    // FIX: Faqat Chrome uchun ishlatish, telefon uchun emas
    if (!kIsWeb) return;
    
    // FIX: Oldingi subscription'ni bekor qilish
    _productsStreamSubscription?.cancel();
    _productsStreamSubscription = null;
    
    try {
      final repository = ServiceLocator.instance.productRepository;
      _productsStreamSubscription = repository.watchProducts().listen(
        (result) {
          try {
            result.fold(
              (failure) {
                debugPrint('⚠️ Products stream error: ${failure.message}');
              },
              (domainProducts) {
                debugPrint('✅ Products realtime update: ${domainProducts.length} products');
                // Domain Product'larni Product model'ga o'tkazish
                try {
                  final products = domainProducts.map((domainProduct) {
                    return Product(
                      id: domainProduct.id,
                      name: domainProduct.name,
                      departmentId: domainProduct.departmentId,
                      parts: domainProduct.partsRequired,
                    );
                  }).toList();
                  
                  if (mounted) {
                    setState(() {
                      _webProducts = products;
                    });
                  }
                } catch (e) {
                  debugPrint('❌ Error mapping products: $e');
                }
              },
            );
          } catch (e) {
            debugPrint('❌ Error in products stream callback: $e');
          }
        },
        onError: (error, stackTrace) {
          debugPrint('❌ Products stream error: $error');
          debugPrint('Stack trace: $stackTrace');
        },
        cancelOnError: false,
      );
      debugPrint('✅ Products realtime stream listener initialized for Chrome');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize products stream: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  /// Chrome'da productslarni yuklash (Supabase'dan)
  Future<void> _loadWebProducts() async {
    if (_isLoadingWebProducts) {
      debugPrint('⚠️ _loadWebProducts: Already loading, skipping...');
      return;
    }
    
    debugPrint('🔄 _loadWebProducts: Starting to load products from Supabase...');
    if (mounted) {
      setState(() {
        _isLoadingWebProducts = true;
      });
    }
    
    try {
      final repository = ServiceLocator.instance.productRepository;
      debugPrint('   Repository obtained, calling getAllProducts()...');
      // FIX: Timeout qo'shish - 15 soniyadan keyin to'xtatish
      final result = await repository.getAllProducts().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⚠️ _loadWebProducts: Timeout after 15 seconds');
          throw TimeoutException('Request timeout', const Duration(seconds: 15));
        },
      );
      
      result.fold(
        (failure) {
          // Xatolik bo'lsa bo'sh ro'yxat
          debugPrint('❌ _loadWebProducts: Failed to load products: ${failure.message}');
          if (mounted) {
            setState(() {
              _webProducts = [];
              _isLoadingWebProducts = false;
            });
          }
        },
        (domainProducts) {
          // Domain Product'larni Product model'ga o'tkazish
          debugPrint('   Received ${domainProducts.length} domain products');
          final products = domainProducts.map((domainProduct) {
            return Product(
              id: domainProduct.id,
              name: domainProduct.name,
              departmentId: domainProduct.departmentId,
              parts: domainProduct.partsRequired,
            );
          }).toList();
          
          debugPrint('✅ _loadWebProducts: Loaded ${products.length} products from Supabase');
          if (mounted) {
            setState(() {
              _webProducts = products;
              _isLoadingWebProducts = false;
            });
            debugPrint('   State updated, _webProducts.length = ${_webProducts.length}');
          } else {
            debugPrint('   Widget not mounted, skipping setState');
          }
        },
      );
    } catch (e, stackTrace) {
      debugPrint('❌ _loadWebProducts: Error loading products: $e');
      debugPrint('   Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _webProducts = [];
          _isLoadingWebProducts = false;
        });
      } else {
        // FIX: Widget unmounted bo'lsa ham loading'ni to'xtatish
        _isLoadingWebProducts = false;
      }
    }
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
    // FIX: Listener ni olib tashlash dispose dan oldin
    _searchController.removeListener(_searchListener);
    _nameController.dispose();
    _searchController.dispose();
    // FIX: Chrome'da stream subscription'ni yopish
    _productsStreamSubscription?.cancel();
    super.dispose();
  }

  /// Filtrlangan va tartiblangan productlarni olish
  /// FIX: Chrome'da state'dan olish
  List<Product> _getFilteredProducts() {
    // FIX: Chrome'da Hive box ochilmaydi - state'dan olish
    if (kIsWeb) {
      debugPrint('🔍 _getFilteredProducts (Chrome): _webProducts.length = ${_webProducts.length}');
      // Chrome'da state'dan olish
      List<Product> products = List.from(_webProducts);

      // Qidiruv
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

      // Tartiblash
      if (_selectedSortOption != null) {
        products = _productService.sortProducts(
          products,
          _selectedSortOption!.ascending,
        );
      }

      return products;
    }
    
    // Mobile/Desktop - service'dan olish
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
  /// FIX: Duplicate prevention - loading state bilan
  Future<void> _addProduct() async {
    // FIX: Agar yaratish jarayoni davom etayotgan bo'lsa, qayta bosilishini oldini olish
    if (_isCreatingProduct) {
      debugPrint('⚠️ Product creation already in progress, ignoring duplicate request');
      return;
    }

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

    // FIX: Loading state'ni o'rnatish
    if (mounted) {
      setState(() {
        _isCreatingProduct = true;
      });
    }

    try {
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

          // FIX: UI ni darhol yangilash - dialog yopilishidan oldin
          setState(() {});
          Navigator.pop(context);
          // FIX: Dialog yopilgandan keyin yana bir marta yangilash
          if (mounted) {
            setState(() {});
          }
          _showSnackBar('Product added successfully', Colors.green);
        } else {
          _showSnackBar('Failed to add product. Please try again.', Colors.red);
        }
      }
    } finally {
      // FIX: Loading state'ni tozalash
      if (mounted) {
        setState(() {
          _isCreatingProduct = false;
        });
      }
    }
  }

  /// Product ID bo'yicha Hive box index topish
  /// FIX: Filtered list index emas, real Hive index qaytaradi
  int? _findHiveIndexById(String productId) {
    try {
      if (!Hive.isBoxOpen('productsBox')) {
        return null;
      }
      final box = _boxService.productsBox;
      for (int i = 0; i < box.length; i++) {
        final product = box.getAt(i);
        if (product != null && product.id == productId) {
          return i;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Mahsulotni o'chirish
  Future<void> _deleteProduct(Product product) async {
    if (!mounted) return;
    
    try {
      // FIX: Filtered list index emas, real Hive index ishlatish
      final hiveIndex = _findHiveIndexById(product.id);
      
      if (hiveIndex == null) {
        if (mounted) {
          _showSnackBar('Product not found in storage', Colors.red);
        }
        return;
      }
      
      // Departmentdan olib tashlash
      await _departmentService.removeProductFromDepartment(
        product.departmentId,
        product.id,
      );
      
      // FIX: Real Hive index ishlatish
      final success = await _productService.deleteProduct(hiveIndex);
        if (mounted) {
          if (success) {
            // FIX: UI ni darhol yangilash
            setState(() {});
            // FIX: Chrome'da productslarni qayta yuklash
            if (kIsWeb) {
              await _loadWebProducts();
            }
            _showSnackBar('Product deleted', Colors.orange);
          } else {
            _showSnackBar('Failed to delete product. Please try again.', Colors.red);
          }
        }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error deleting product: ${e.toString()}', Colors.red);
      }
    }
  }

  /// Qismlar tanlash dialogini ko'rsatish
  /// 
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
        _showSnackBar('No parts available. Please add parts first.', Colors.orange);
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
            child: Builder(
              builder: (context) {
                // FIX: Chrome'da Hive ishlamaydi - fallback qo'shish
                // FIX: Faqat Chrome uchun fallback ishlatish, telefon uchun ValueListenableBuilder
                if (kIsWeb) {
                  // Chrome - to'g'ridan-to'g'ri state'dan olish
                  return _buildWebProductsFallback();
                }
                
                // FIX: Telefon uchun Hive box ochilmagan bo'lsa, bo'sh ko'rsatish
                if (!Hive.isBoxOpen('productsBox')) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                // Mobile/Desktop - ValueListenableBuilder ishlatish
                return ValueListenableBuilder(
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
                          // FIX: Refresh if product was updated
                          if (result == true && mounted) {
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
                  onPressed: _isCreatingProduct ? null : () {
                    _addProduct();
                  },
                  child: _isCreatingProduct
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Chrome/Web uchun fallback widget
  /// FIX: Chrome'da Hive ishlamaydi - to'g'ridan-to'g'ri state'dan olish
  Widget _buildWebProductsFallback() {
    debugPrint('🔍 _buildWebProductsFallback called');
    debugPrint('   _isLoadingWebProducts: $_isLoadingWebProducts');
    debugPrint('   _webProducts.length: ${_webProducts.length}');
    
    // FIX: Chrome'da productslar yuklanayotgan bo'lsa, loading ko'rsatish
    if (kIsWeb && _isLoadingWebProducts) {
      debugPrint('   Showing loading indicator');
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    // FIX: Agar productslar bo'sh bo'lsa va yuklanayotgan bo'lmasa, yuklashga harakat qilish
    if (kIsWeb && _webProducts.isEmpty && !_isLoadingWebProducts) {
      debugPrint('   Products empty, attempting to load...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadWebProducts();
        }
      });
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final products = _getFilteredProducts();
    debugPrint('   Filtered products.length: ${products.length}');

    if (products.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          if (mounted) {
            // FIX: Chrome'da productslarni qayta yuklash
            if (kIsWeb) {
              await _loadWebProducts();
            }
            setState(() {});
          }
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: const EmptyStateWidget(
              icon: Icons.inventory,
              title: 'No products yet',
              subtitle: 'Tap the + button to add a product',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (mounted) {
          // FIX: Chrome'da productslarni qayta yuklash
          if (kIsWeb) {
            await _loadWebProducts();
          }
          setState(() {});
        }
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: products.length,
        itemBuilder: (context, index) {
          if (!mounted) {
            return const SizedBox.shrink();
          }
          
          try {
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
                    // FIX: Refresh if product was updated
                    if (result == true && mounted) {
                      if (kIsWeb) {
                        await _loadWebProducts();
                      }
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
          } catch (e) {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}
