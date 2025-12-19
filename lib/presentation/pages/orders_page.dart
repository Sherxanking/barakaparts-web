/// OrdersPage - Buyurtmalarni yaratish va boshqarish sahifasi
/// 
/// Bu sahifa quyidagi funksiyalarni ta'minlaydi:
/// - Yangi buyurtma yaratish (Department → Product → Quantity)
/// - Buyurtmalarni ko'rish va boshqarish
/// - Buyurtmalarni qidirish, filtrlash va tartiblash
/// - Buyurtmalarni complete qilish (stock reduction)
/// - Real-time yangilanishlar (ValueListenableBuilder)
import 'dart:async' show StreamSubscription, TimeoutException;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/department_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/order_model.dart';
import '../../data/services/hive_box_service.dart';
import '../../data/services/order_service.dart';
import '../../data/services/department_service.dart';
import '../../data/services/product_service.dart';
import '../../data/services/part_calculator_service.dart';
import '../../data/services/part_service.dart';
import '../../core/di/service_locator.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/filter_chip_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/order_item_widget.dart';
import '../../l10n/app_localizations.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  // Services
  final HiveBoxService _boxService = HiveBoxService();
  final OrderService _orderService = OrderService();
  final DepartmentService _departmentService = DepartmentService();
  final ProductService _productService = ProductService();
  final PartService _partService = PartService();
  late final PartCalculatorService _partCalculatorService;

  // Form state - Order yaratish uchun
  String? selectedDepartmentId;
  String? selectedProductId;
  int quantity = 1;

  // Search, Filter, Sort state
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter;
  String? _selectedDepartmentFilter;
  SortOption? _selectedSortOption;
  
  // Chrome uchun state
  List<Order> _webOrders = [];
  bool _isLoadingWebOrders = false;
  
  // Chrome uchun real-time stream subscription
  StreamSubscription? _ordersStreamSubscription;
  
  // Order completion loading state (optimization)
  String? _completingOrderId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // FIX: PartCalculatorService ni ishga tushirish
    _partCalculatorService = PartCalculatorService(_partService);
    
    // FIX: Chrome'da orderslarni yuklash
    // FIX: Faqat Chrome uchun, telefon uchun emas
    if (kIsWeb) {
      // PostFrameCallback orqali yuklash - UI render bo'lgandan keyin
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && kIsWeb) {
          try {
            _loadWebOrders();
            _listenToOrdersStream();
          } catch (e) {
            debugPrint('❌ Error initializing web orders: $e');
          }
        }
      });
    }
  }
  
  /// Chrome'da orderslarni yuklash (Supabase'dan)
  Future<void> _loadWebOrders() async {
    if (_isLoadingWebOrders) {
      debugPrint('⚠️ _loadWebOrders: Already loading, skipping...');
      return;
    }
    
    debugPrint('🔄 _loadWebOrders: Starting to load orders from Supabase...');
    if (mounted) {
      setState(() {
        _isLoadingWebOrders = true;
      });
    }
    
    try {
      final repository = ServiceLocator.instance.orderRepository;
      debugPrint('   Repository obtained, calling getAllOrders()...');
      // FIX: Timeout qo'shish - 15 soniyadan keyin to'xtatish
      final result = await repository.getAllOrders().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⚠️ _loadWebOrders: Timeout after 15 seconds');
          throw TimeoutException('Request timeout', const Duration(seconds: 15));
        },
      );
      
      result.fold(
        (failure) {
          // Xatolik bo'lsa bo'sh ro'yxat
          debugPrint('❌ _loadWebOrders: Failed to load orders: ${failure.message}');
          if (mounted) {
            setState(() {
              _webOrders = [];
              _isLoadingWebOrders = false;
            });
          }
        },
        (domainOrders) {
          // Domain Order'larni Order model'ga o'tkazish
          debugPrint('   Received ${domainOrders.length} domain orders');
          final orders = domainOrders.map((domainOrder) {
            // FIX: Order model'da productId yo'q, productName bor
            // Domain Order'dan productName to'g'ridan-to'g'ri olish
            return Order(
              id: domainOrder.id,
              departmentId: domainOrder.departmentId,
              productName: domainOrder.productName,
              quantity: domainOrder.quantity,
              status: domainOrder.status, // FIX: status allaqachon String
              createdAt: domainOrder.createdAt,
            );
          }).toList();
          
          debugPrint('✅ _loadWebOrders: Loaded ${orders.length} orders from Supabase');
          if (mounted) {
            setState(() {
              _webOrders = orders;
              _isLoadingWebOrders = false;
            });
            debugPrint('   State updated, _webOrders.length = ${_webOrders.length}');
          } else {
            debugPrint('   Widget not mounted, skipping setState');
          }
        },
      );
    } catch (e, stackTrace) {
      debugPrint('❌ _loadWebOrders: Error loading orders: $e');
      debugPrint('   Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _webOrders = [];
          _isLoadingWebOrders = false;
        });
      } else {
        // FIX: Widget unmounted bo'lsa ham loading'ni to'xtatish
        _isLoadingWebOrders = false;
      }
    }
  }
  
  /// Chrome'da orders stream'ga quloq solish (real-time updates)
  void _listenToOrdersStream() {
    // FIX: Faqat Chrome uchun ishlatish, telefon uchun emas
    if (!kIsWeb) return;
    
    // FIX: Oldingi subscription'ni bekor qilish
    _ordersStreamSubscription?.cancel();
    _ordersStreamSubscription = null;
    
    try {
      final repository = ServiceLocator.instance.orderRepository;
      _ordersStreamSubscription = repository.watchOrders().listen(
        (result) {
          try {
            result.fold(
              (failure) {
                debugPrint('⚠️ Orders stream error: ${failure.message}');
              },
              (domainOrders) {
                debugPrint('✅ Orders realtime update: ${domainOrders.length} orders');
                // Domain Order'larni Order model'ga o'tkazish
                try {
                  final orders = domainOrders.map((domainOrder) {
                    // FIX: Order model'da productId yo'q, productName bor
                    // Domain Order'dan productName to'g'ridan-to'g'ri olish
                    return Order(
                      id: domainOrder.id,
                      departmentId: domainOrder.departmentId,
                      productName: domainOrder.productName,
                      quantity: domainOrder.quantity,
                      status: domainOrder.status, // FIX: status allaqachon String
                      createdAt: domainOrder.createdAt,
                    );
                  }).toList();
                  
                  if (mounted) {
                    setState(() {
                      _webOrders = orders;
                    });
                  }
                } catch (e) {
                  debugPrint('❌ Error mapping orders: $e');
                }
              },
            );
          } catch (e) {
            debugPrint('❌ Error in orders stream callback: $e');
          }
        },
        onError: (error, stackTrace) {
          debugPrint('❌ Orders stream error: $error');
          debugPrint('Stack trace: $stackTrace');
        },
        cancelOnError: false,
      );
      debugPrint('✅ Orders realtime stream listener initialized for Chrome');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize orders stream: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  void dispose() {
    // FIX: Listener ni olib tashlash dispose dan oldin
    // Bu '_dependents.isEmpty' xatoligini oldini oladi
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    // FIX: Chrome'da stream subscription'ni yopish
    _ordersStreamSubscription?.cancel();
    _ordersStreamSubscription = null;
    super.dispose();
  }

  /// Qidiruv o'zgarganda
  void _onSearchChanged() {
    setState(() {});
  }

  /// Filtrlangan va tartiblangan orderlarni olish
  /// Filtrlangan va tartiblangan orderlarni olish
  /// FIX: Chrome'da state'dan olish
  List<Order> _getFilteredOrders() {
    // FIX: Chrome'da Hive box ochilmaydi - state'dan olish
    if (kIsWeb) {
      debugPrint('🔍 _getFilteredOrders (Chrome): _webOrders.length = ${_webOrders.length}');
      // Chrome'da state'dan olish
      List<Order> orders = List.from(_webOrders);

      // Qidiruv
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        orders = orders.where((order) {
          // FIX: Order model'da productId yo'q, productName bor
          return order.productName.toLowerCase().contains(query);
        }).toList();
      }

      // Status filter
      if (_selectedStatusFilter != null) {
        orders = orders.where((o) => o.status == _selectedStatusFilter).toList();
      }

      // Department filter
      if (_selectedDepartmentFilter != null) {
        orders = orders.where((o) => o.departmentId == _selectedDepartmentFilter).toList();
      }

      // Tartiblash
      if (_selectedSortOption != null) {
        orders = _orderService.sortOrders(
          orders,
          byDate: _selectedSortOption == SortOption.dateAsc || 
                  _selectedSortOption == SortOption.dateDesc,
          ascending: _selectedSortOption!.ascending,
        );
      }

      return orders;
    }
    
    // Mobile/Desktop - service'dan olish
    List<Order> orders = _orderService.searchAndFilterOrders(
      query: _searchController.text.isEmpty ? null : _searchController.text,
      status: _selectedStatusFilter,
      departmentId: _selectedDepartmentFilter,
    );

    // Tartiblash
    if (_selectedSortOption != null) {
      orders = _orderService.sortOrders(
        orders,
        byDate: _selectedSortOption == SortOption.dateAsc || 
                _selectedSortOption == SortOption.dateDesc,
        ascending: _selectedSortOption!.ascending,
      );
    }

    return orders;
  }

  /// Yangi buyurtma yaratish
  Future<void> _createOrder() async {
    // Validatsiya
    if (selectedDepartmentId == null || selectedProductId == null) {
      _showSnackBar(AppLocalizations.of(context)?.translate('pleaseSelectDepartmentAndProduct') ?? 'Please select a department and product', Colors.red);
      return;
    }

    final department = _departmentService.getDepartmentById(selectedDepartmentId!);
    final product = _productService.getProductById(selectedProductId!);

    if (department == null || product == null) {
      _showSnackBar(AppLocalizations.of(context)?.translate('selectedDepartmentOrProductNotFound') ?? 'Selected department or product not found', Colors.red);
      return;
    }

    // FIX: Qismlar yetishmovchiligini hisoblash va dialog ko'rsatish
    final calculationResult = _partCalculatorService.calculateShortage(product, quantity);
    
    // Yetishmovchilik bor bo'lsa, dialog ko'rsatish
    if (calculationResult.hasShortage) {
      final shouldProceed = await _showShortageDialog(calculationResult.shortages);
      if (shouldProceed != true) {
        return; // Foydalanuvchi bekor qildi
      }
    }

    // Order yaratish
    final order = Order(
      id: const Uuid().v4(),
      departmentId: department.id,
      productName: product.name,
      quantity: quantity,
      status: 'pending',
    );

    // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
    final success = await _orderService.addOrder(order);
    if (mounted) {
      if (success) {
        // Formni tozalash
        setState(() {
          selectedDepartmentId = null;
          selectedProductId = null;
          quantity = 1;
        });
        // FIX: Chrome'da orderslarni qayta yuklash
        if (kIsWeb) {
          await _loadWebOrders();
        }
        // Yetishmovchilik bo'lmagan bo'lsa muvaffaqiyat xabari
        if (!calculationResult.hasShortage) {
          _showSnackBar(AppLocalizations.of(context)?.translate('orderCreated') ?? 'Order created successfully', Colors.green);
        }
      } else {
        _showSnackBar(AppLocalizations.of(context)?.translate('failedToCreateOrder') ?? 'Failed to create order. Please try again.', Colors.red);
      }
    }
  }

  /// Buyurtmani complete qilish
  /// OPTIMIZATION: Loading indicator va background refresh
  Future<void> _completeOrder(Order order) async {
    // Loading state
    if (mounted) {
      setState(() {
        _completingOrderId = order.id;
      });
    }
    
    try {
      // OPTIMIZATION: Batch update bilan tezroq ishlaydi
      final success = await _orderService.completeOrder(order);
      
      if (mounted) {
        if (success) {
          // OPTIMIZATION: Chrome'da background'da refresh (blocking emas)
          if (kIsWeb) {
            // Background'da refresh - UI'ni bloklamaydi
            _loadWebOrders().catchError((e) {
              debugPrint('⚠️ Background refresh failed: $e');
            });
          }
          _showSnackBar(AppLocalizations.of(context)?.translate('orderCompleted') ?? 'Order completed successfully', Colors.green);
        } else {
          _showSnackBar(AppLocalizations.of(context)?.translate('failedToCompleteOrder') ?? 'Failed to complete order. Check parts availability.', Colors.red);
        }
      }
    } finally {
      // Loading state'ni tozalash
      if (mounted) {
        setState(() {
          _completingOrderId = null;
        });
      }
    }
  }

  /// Buyurtmani o'chirish
  Future<void> _deleteOrder(Order order) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.translate('deleteOrder') ?? 'Delete Order'),
        content: Text('${AppLocalizations.of(context)?.translate('deleteOrderConfirm') ?? 'Are you sure you want to delete order for'} ${order.productName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)?.translate('delete') ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
      final success = await _orderService.deleteOrderById(order.id);
      if (mounted) {
        if (success) {
          // FIX: Chrome'da orderslarni qayta yuklash
          if (kIsWeb) {
            await _loadWebOrders();
          }
          _showSnackBar(AppLocalizations.of(context)?.translate('orderDeleted') ?? 'Order deleted', Colors.orange);
        } else {
          _showSnackBar(AppLocalizations.of(context)?.translate('failedToDeleteOrder') ?? 'Failed to delete order. Please try again.', Colors.red);
        }
      }
    }
  }

  /// Qismlar yetishmovchiligi dialogini ko'rsatish
  /// 
  /// [shortages] - Yetishmovchilik ro'yxati
  /// Qaytaradi: true - davom etish, false/null - bekor qilish
  Future<bool?> _showShortageDialog(List<PartShortage> shortages) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.translate('partsShortage') ?? 'Parts Shortage',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.translate('partsInsufficient') ?? 'The following parts are insufficient:',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                // FIX: ListView.builder o'rniga Column ishlatish - overflow muammosini oldini olish
                ...shortages.map((shortage) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shortage.partName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${AppLocalizations.of(context)?.translate('required') ?? 'Required'}: ${shortage.required}',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${AppLocalizations.of(context)?.translate('available') ?? 'Available'}: ${shortage.available}',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${AppLocalizations.of(context)?.translate('short') ?? 'Short'}: ${shortage.shortage}',
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)?.translate('doYouWantToProceedAnyway') ?? 'Do you want to proceed anyway?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)?.translate('proceedAnyway') ?? 'Proceed',
              style: TextStyle(color: Colors.orange.shade700),
            ),
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
        title: Text(AppLocalizations.of(context)?.translate('orders') ?? 'Orders'),
        elevation: 2,
      ),
      body: Column(
        children: [
          // Search va Filter section
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                // Search bar
                SearchBarWidget(
                  controller: _searchController,
                  hintText: 'Search orders...',
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status filter
                      FilterChipWidget(
                        label: 'All',
                        selected: _selectedStatusFilter == null,
                        onSelected: (selected) {
              setState(() {
                            _selectedStatusFilter = selected ? null : _selectedStatusFilter;
              });
            },
          ),
                      const SizedBox(width: 8),
                      FilterChipWidget(
                        label: AppLocalizations.of(context)?.translate('pending') ?? 'Pending',
                        selected: _selectedStatusFilter == 'pending',
                        onSelected: (selected) {
                          setState(() {
                            _selectedStatusFilter = selected ? 'pending' : null;
                          });
                        },
                        icon: Icons.pending,
                      ),
                      const SizedBox(width: 8),
                      FilterChipWidget(
                        label: AppLocalizations.of(context)?.translate('completed') ?? 'Completed',
                        selected: _selectedStatusFilter == 'completed',
                        onSelected: (selected) {
                          setState(() {
                            _selectedStatusFilter = selected ? 'completed' : null;
                          });
                        },
                        icon: Icons.check_circle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Sort dropdown
                SortDropdownWidget(
                  selectedOption: _selectedSortOption,
                  onChanged: (option) {
                    setState(() {
                      _selectedSortOption = option;
                    });
                  },
                  options: const [
                    SortOption.dateDesc,
                    SortOption.dateAsc,
                    SortOption.nameAsc,
                    SortOption.nameDesc,
                  ],
                ),
              ],
            ),
          ),

          // FIX: Main content - CustomScrollView + SliverList ishlatish
          // Bu nested scroll muammosini hal qiladi va performance ni yaxshilaydi
          Expanded(
            child: Builder(
              builder: (context) {
                // FIX: Chrome'da Hive ishlamaydi - fallback qo'shish
                // FIX: Faqat Chrome uchun fallback ishlatish, telefon uchun ValueListenableBuilder
                if (kIsWeb) {
                  // Chrome - to'g'ridan-to'g'ri state'dan olish
                  return _buildWebOrdersFallback();
                }
                
                // FIX: Telefon uchun Hive box ochilmagan bo'lsa, loading ko'rsatish
                if (!Hive.isBoxOpen('ordersBox')) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                // Mobile/Desktop - ValueListenableBuilder ishlatish
                return ValueListenableBuilder<Box<Order>>(
                  valueListenable: _boxService.ordersListenable,
                  builder: (context, box, _) {
                    final orders = _getFilteredOrders();
                
                // FIX: RefreshIndicator faqat list boshida ishlashi uchun
                // CustomScrollView + SliverList ishlatish
                return RefreshIndicator(
                  // FIX: RefreshIndicator faqat list boshida ishlashi uchun physics
                  onRefresh: () async {
                    setState(() {});
                    await Future.delayed(const Duration(milliseconds: 300));
                  },
                  // FIX: BouncingScrollPhysics + AlwaysScrollableScrollPhysics
                  // Bu scroll ni silliq qiladi va refresh ni to'g'ri ishlatadi
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // Create Order Section - SliverToBoxAdapter
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)?.translate('createNewOrder') ?? 'Create New Order',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Department dropdown
                                  ValueListenableBuilder(
                                    valueListenable: _boxService.departmentsListenable,
                                    builder: (context, Box<Department> deptBox, _) {
                                      final departments = deptBox.values.toList();
                                      return DropdownButtonFormField<String>(
                                        initialValue: selectedDepartmentId,
                                        decoration: InputDecoration(
                                          labelText: AppLocalizations.of(context)?.translate('selectDepartment') ?? 'Select Department',
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(Icons.business),
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
                                            selectedProductId = null; // Reset product
                                          });
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Product dropdown (filtered by department)
                                  ValueListenableBuilder(
                                    valueListenable: _boxService.productsListenable,
                                    builder: (context, Box<Product> prodBox, _) {
                                      final products = selectedDepartmentId != null
                                          ? _productService.getProductsByDepartment(selectedDepartmentId!)
                                          : <Product>[];
                                      
                                      return DropdownButtonFormField<String>(
                                        key: ValueKey('product_${selectedDepartmentId}_${selectedProductId}'), // FIX: Key qo'shish - dropdown yangilanishi uchun
                                        initialValue: selectedProductId,
                                        decoration: InputDecoration(
                                          labelText: AppLocalizations.of(context)?.translate('selectProduct') ?? 'Select Product',
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(Icons.inventory),
                                        ),
                                        items: products.map((product) {
                                          return DropdownMenuItem(
                                            value: product.id,
                                            child: Text(product.name),
                                          );
                                        }).toList(),
                                        onChanged: selectedDepartmentId != null
                                            ? (value) {
                                                setState(() {
                                                  selectedProductId = value;
                                                });
                                              }
                                            : null,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Quantity selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                                      Text('${AppLocalizations.of(context)?.translate('quantity') ?? 'Quantity'}: ', style: const TextStyle(fontSize: 16)),
              IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  if (quantity > 1) {
                    setState(() => quantity--);
                  }
                },
              ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          '$quantity',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
              IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  setState(() => quantity++);
                },
              ),
            ],
          ),
                                  const SizedBox(height: 16),
                                  
                                  // Create order button
                                  ElevatedButton.icon(
                                    onPressed: _createOrder,
                                    icon: const Icon(Icons.add_shopping_cart),
                                    label: Text(AppLocalizations.of(context)?.translate('createOrder') ?? 'Create Order'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Orders List Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            AppLocalizations.of(context)?.translate('ordersList') ?? 'Orders List',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      
                      // FIX: Orders list - SliverList ishlatish
                      // Bu ListView.builder o'rniga ishlatiladi va performance ni yaxshilaydi
                      if (orders.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyStateWidget(
                            icon: Icons.shopping_cart_outlined,
                            title: box.isEmpty 
                                ? 'No orders yet' 
                                : 'No orders match your filters',
                            subtitle: box.isEmpty
                                ? 'Create your first order using the form above'
                                : 'Try adjusting your search or filters',
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final order = orders[index];
                              final department = _departmentService.getDepartmentById(order.departmentId);
                              
                              // FIX: OrderItemWidget ishlatish - rebuild optimizatsiyasi
                              // OPTIMIZATION: Loading state uzatish
                              return OrderItemWidget(
                                order: order,
                                department: department,
                                onComplete: () => _completeOrder(order),
                                onDelete: () => _deleteOrder(order),
                                isCompleting: _completingOrderId == order.id, // Loading state
                              );
                            },
                            childCount: orders.length,
                          ),
                        ),
                    ],
                  ),
                );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Chrome/Web uchun fallback widget
  /// FIX: Chrome'da Hive ishlamaydi - to'g'ridan-to'g'ri state'dan olish
  Widget _buildWebOrdersFallback() {
    debugPrint('🔍 _buildWebOrdersFallback called');
    debugPrint('   _isLoadingWebOrders: $_isLoadingWebOrders');
    debugPrint('   _webOrders.length: ${_webOrders.length}');
    
    // FIX: Chrome'da orderslar yuklanayotgan bo'lsa, loading ko'rsatish
    if (kIsWeb && _isLoadingWebOrders) {
      debugPrint('   Showing loading indicator');
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    // FIX: Agar orderslar bo'sh bo'lsa va yuklanayotgan bo'lmasa, yuklashga harakat qilish
    if (kIsWeb && _webOrders.isEmpty && !_isLoadingWebOrders) {
      debugPrint('   Orders empty, attempting to load...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadWebOrders();
        }
      });
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final orders = _getFilteredOrders();
    debugPrint('   Filtered orders.length: ${orders.length}');
    
    return RefreshIndicator(
      onRefresh: () async {
        if (mounted) {
          // FIX: Chrome'da orderslarni qayta yuklash
          if (kIsWeb) {
            await _loadWebOrders();
          }
          setState(() {});
        }
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Create Order Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.translate('createNewOrder') ?? 'Create New Order',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Department dropdown
                      ValueListenableBuilder(
                        valueListenable: _boxService.departmentsListenable,
                        builder: (context, Box<Department> deptBox, _) {
                          final departments = deptBox.values.toList();
                          return DropdownButtonFormField<String>(
                            initialValue: selectedDepartmentId,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)?.translate('selectDepartment') ?? 'Select Department',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.business),
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
                                selectedProductId = null; // Reset product
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Product dropdown (filtered by department)
                      if (selectedDepartmentId != null)
                        ValueListenableBuilder(
                          valueListenable: _boxService.productsListenable,
                          builder: (context, Box<Product> prodBox, _) {
                            final products = _productService.getProductsByDepartment(selectedDepartmentId!);
                            
                            return DropdownButtonFormField<String>(
                              key: ValueKey('product_${selectedDepartmentId}_${selectedProductId}'), // FIX: Key qo'shish - dropdown yangilanishi uchun
                              initialValue: selectedProductId,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)?.translate('selectProduct') ?? 'Select Product',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.inventory),
                              ),
                              items: products.map((product) {
                                return DropdownMenuItem(
                                  value: product.id,
                                  child: Text(product.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedProductId = value;
                                });
                              },
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      // Quantity input
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            quantity = int.tryParse(value) ?? 1;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Create button
                      ElevatedButton(
                        onPressed: selectedDepartmentId != null &&
                                selectedProductId != null
                            ? _createOrder
                            : null,
                        child: Text(AppLocalizations.of(context)?.translate('createOrder') ?? 'Create Order'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Orders List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                AppLocalizations.of(context)?.translate('ordersList') ?? 'Orders List',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Orders list
          if (orders.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: const EmptyStateWidget(
                icon: Icons.shopping_cart_outlined,
                title: 'No orders yet',
                subtitle: 'Create your first order using the form above',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final order = orders[index];
                  final department = _departmentService.getDepartmentById(order.departmentId);
                  
                  return OrderItemWidget(
                    order: order,
                    department: department,
                    onComplete: () => _completeOrder(order),
                    onDelete: () => _deleteOrder(order),
                    isCompleting: _completingOrderId == order.id, // Loading state
                  );
                },
                childCount: orders.length,
              ),
            ),
        ],
      ),
    );
  }
}
