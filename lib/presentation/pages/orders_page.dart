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
import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../../core/services/auth_state_service.dart';
import '../../domain/entities/order.dart' as domain;
import '../../domain/entities/user.dart' as domain;
import '../../domain/repositories/order_repository.dart';
import '../../infrastructure/cache/hive_order_cache.dart';
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
  // Repository
  final OrderRepository _orderRepository = ServiceLocator.instance.orderRepository;
  
  // Services (for backward compatibility - will be removed gradually)
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
  
  // State for initial load only
  bool _isInitialLoading = true;
  
  // Order completion loading state (optimization)
  String? _completingOrderId;
  
  /// Check if current user can create orders
  bool get _canCreateOrders {
    final user = AuthStateService().currentUser;
    return user != null; // All authenticated users can create orders
  }
  
  /// Check if current user can complete orders
  bool get _canCompleteOrders {
    final user = AuthStateService().currentUser;
    return user != null && (user.isManager || user.isBoss);
  }
  
  /// Check if current user can delete orders
  bool get _canDeleteOrders {
    final user = AuthStateService().currentUser;
    return user != null && user.isBoss;
  }
  
  /// Get current user for department filtering (Manager only)
  domain.User? get _currentUser => AuthStateService().currentUser;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // FIX: PartCalculatorService ni ishga tushirish
    _partCalculatorService = PartCalculatorService(_partService);
    
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

  @override
  void dispose() {
    // Cancel listener and subscription
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    // StreamBuilder handles subscription automatically
    super.dispose();
  }

  /// Qidiruv o'zgarganda
  void _onSearchChanged() {
    setState(() {});
  }

  /// Filtrlangan va tartiblangan orderlarni olish
  /// Repository pattern - works for both web and mobile
  /// Manager uchun department filter qo'shildi
  List<domain.Order> _getFilteredOrders(List<domain.Order> orders) {
    // Start with provided orders
    
    // Manager uchun department filter (faqat o'z department'idagi orders)
    final user = _currentUser;
    if (user != null && user.isManager && user.departmentId != null) {
      orders = orders.where((o) => o.departmentId == user.departmentId).toList();
    }

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      orders = orders.where((order) {
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

    // Sort
    if (_selectedSortOption != null) {
      orders.sort((a, b) {
        final ascending = _selectedSortOption!.ascending;
        switch (_selectedSortOption!) {
          case SortOption.dateAsc:
          case SortOption.dateDesc:
            return ascending 
                ? a.createdAt.compareTo(b.createdAt)
                : b.createdAt.compareTo(a.createdAt);
          case SortOption.nameAsc:
          case SortOption.nameDesc:
            return ascending 
                ? a.productName.compareTo(b.productName)
                : b.productName.compareTo(a.productName);
          default:
            return 0;
        }
      });
    }

    return orders;
  }
  
  /// Convert domain Order to Order model (for backward compatibility)
  Order _domainToModel(domain.Order domainOrder) {
    return Order(
      id: domainOrder.id,
      departmentId: domainOrder.departmentId,
      productName: domainOrder.productName,
      quantity: domainOrder.quantity,
      status: domainOrder.status,
      createdAt: domainOrder.createdAt,
    );
  }

  /// Yangi buyurtma yaratish
  /// Repository pattern - works for both web and mobile
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

    // Qismlar yetishmovchiligini hisoblash va dialog ko'rsatish
    final calculationResult = _partCalculatorService.calculateShortage(product, quantity);
    
    // Yetishmovchilik bor bo'lsa, dialog ko'rsatish
    if (calculationResult.hasShortage) {
      final shouldProceed = await _showShortageDialog(calculationResult.shortages);
      if (shouldProceed != true) {
        return; // Foydalanuvchi bekor qildi
      }
    }

    // Domain Order yaratish
    final domainOrder = domain.Order(
      id: const Uuid().v4(),
      productId: product.id,
      productName: product.name,
      departmentId: department.id,
      quantity: quantity,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    // Use repository to create order
    final result = await _orderRepository.createOrder(domainOrder);
    
    if (mounted) {
      result.fold(
        (failure) {
          _showSnackBar('Failed to create order: ${failure.message}', Colors.red);
        },
        (createdOrder) {
          // Formni tozalash
          setState(() {
            selectedDepartmentId = null;
            selectedProductId = null;
            quantity = 1;
          });
          // Yetishmovchilik bo'lmagan bo'lsa muvaffaqiyat xabari
          if (!calculationResult.hasShortage) {
            _showSnackBar(AppLocalizations.of(context)?.translate('orderCreated') ?? 'Order created successfully', Colors.green);
          }
        },
      );
    }
  }

  /// Buyurtmani complete qilish
  /// Repository pattern - works for both web and mobile
  Future<void> _completeOrder(domain.Order order) async {
    // Loading state
    if (mounted) {
      setState(() {
        _completingOrderId = order.id;
      });
    }
    
    try {
      // Use repository to complete order
      final result = await _orderRepository.completeOrder(order.id);
      
      if (mounted) {
        result.fold(
          (failure) {
            _showSnackBar('Failed to complete order: ${failure.message}', Colors.red);
          },
          (completedOrder) {
            _showSnackBar(AppLocalizations.of(context)?.translate('orderCompleted') ?? 'Order completed successfully', Colors.green);
          },
        );
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
  /// Repository pattern - works for both web and mobile
  Future<void> _deleteOrder(domain.Order order) async {
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
      // Use repository to delete order
      final result = await _orderRepository.deleteOrder(order.id);
      
      if (mounted) {
        result.fold(
          (failure) {
            _showSnackBar('Failed to delete order: ${failure.message}', Colors.red);
          },
          (_) {
            _showSnackBar(AppLocalizations.of(context)?.translate('orderDeleted') ?? 'Order deleted', Colors.orange);
          },
        );
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
    return StreamBuilder<Either<Failure, List<domain.Order>>>(
      stream: _orderRepository.watchOrders(),
      builder: (context, snapshot) {
        // Handle loading state
        if (_isInitialLoading && !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)?.translate('orders') ?? 'Orders'),
              elevation: 2,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        
        // Handle error state
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)?.translate('orders') ?? 'Orders'),
              elevation: 2,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _isInitialLoading = true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Handle data
        final orders = snapshot.data?.fold(
          (failure) {
            // Show error but don't crash
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showSnackBar('Error: ${failure.message}', Colors.red);
              }
            });
            return <domain.Order>[];
          },
          (orders) => orders,
        ) ?? <domain.Order>[];
        
        final filteredOrders = _getFilteredOrders(orders);
        
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
                    // RefreshIndicator with CustomScrollView + SliverList
                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() => _isInitialLoading = true);
                        await Future.delayed(const Duration(milliseconds: 500));
                        setState(() => _isInitialLoading = false);
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
                      
                      // Orders list - SliverList
                      if (filteredOrders.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyStateWidget(
                            icon: Icons.shopping_cart_outlined,
                            title: orders.isEmpty 
                                ? 'No orders yet' 
                                : 'No orders match your filters',
                            subtitle: orders.isEmpty
                                ? 'Create your first order using the form above'
                                : 'Try adjusting your search or filters',
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final domainOrder = filteredOrders[index];
                              final order = _domainToModel(domainOrder);
                              final department = _departmentService.getDepartmentById(order.departmentId);
                              
                              return OrderItemWidget(
                                order: order,
                                department: department,
                                onComplete: _canCompleteOrders ? () => _completeOrder(domainOrder) : null,
                                onDelete: _canDeleteOrders ? () => _deleteOrder(domainOrder) : null,
                                isCompleting: _completingOrderId == domainOrder.id,
                              );
                            },
                            childCount: filteredOrders.length,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}
