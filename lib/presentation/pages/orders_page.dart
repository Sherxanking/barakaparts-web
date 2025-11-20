/// OrdersPage - Buyurtmalarni yaratish va boshqarish sahifasi
/// 
/// Bu sahifa quyidagi funksiyalarni ta'minlaydi:
/// - Yangi buyurtma yaratish (Department → Product → Quantity)
/// - Buyurtmalarni ko'rish va boshqarish
/// - Buyurtmalarni qidirish, filtrlash va tartiblash
/// - Buyurtmalarni complete qilish (stock reduction)
/// - Real-time yangilanishlar (ValueListenableBuilder)
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
import '../widgets/search_bar_widget.dart';
import '../widgets/filter_chip_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/order_item_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // FIX: PartCalculatorService ni ishga tushirish
    _partCalculatorService = PartCalculatorService(_partService);
  }

  @override
  void dispose() {
    // FIX: Listener ni olib tashlash dispose dan oldin
    // Bu '_dependents.isEmpty' xatoligini oldini oladi
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Qidiruv o'zgarganda
  void _onSearchChanged() {
    setState(() {});
  }

  /// Filtrlangan va tartiblangan orderlarni olish
  List<Order> _getFilteredOrders() {
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
      _showSnackBar('Please select a department and product', Colors.red);
      return;
    }

    final department = _departmentService.getDepartmentById(selectedDepartmentId!);
    final product = _productService.getProductById(selectedProductId!);

    if (department == null || product == null) {
      _showSnackBar('Selected department or product not found', Colors.red);
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
        // Yetishmovchilik bo'lmagan bo'lsa muvaffaqiyat xabari
        if (!calculationResult.hasShortage) {
          _showSnackBar('Order created successfully', Colors.green);
        }
      } else {
        _showSnackBar('Failed to create order. Please try again.', Colors.red);
      }
    }
  }

  /// Buyurtmani complete qilish
  Future<void> _completeOrder(Order order) async {
    final success = await _orderService.completeOrder(order);
    if (success) {
      _showSnackBar('Order completed successfully', Colors.green);
    } else {
      _showSnackBar('Failed to complete order. Check parts availability.', Colors.red);
    }
  }

  /// Buyurtmani o'chirish
  Future<void> _deleteOrder(Order order) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text('Are you sure you want to delete order for ${order.productName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
      final success = await _orderService.deleteOrderById(order.id);
      if (mounted) {
        if (success) {
          _showSnackBar('Order deleted', Colors.orange);
        } else {
          _showSnackBar('Failed to delete order. Please try again.', Colors.red);
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
            const Expanded(
              child: Text(
                'Parts Shortage',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                const Text(
                  'The following parts are insufficient:',
                  style: TextStyle(fontWeight: FontWeight.w500),
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
                                    'Required: ${shortage.required}',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Available: ${shortage.available}',
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
                                  'Short: ${shortage.shortage}',
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
                }).toList(),
                const SizedBox(height: 16),
                const Text(
                  'Do you want to proceed anyway?',
                  style: TextStyle(
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Proceed',
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
        title: const Text('Orders'),
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
                        label: 'Pending',
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
                        label: 'Completed',
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
            child: ValueListenableBuilder<Box<Order>>(
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
                                  const Text(
                                    'Create New Order',
                                    style: TextStyle(
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
                                        value: selectedDepartmentId,
                                        decoration: const InputDecoration(
                                          labelText: 'Select Department',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.business),
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
                                        value: selectedProductId,
                                        decoration: const InputDecoration(
                                          labelText: 'Select Product',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.inventory),
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
                                      const Text('Quantity: ', style: TextStyle(fontSize: 16)),
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
                                    label: const Text('Create Order'),
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
                          child: const Text(
                            'Orders List',
                            style: TextStyle(
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
                              return OrderItemWidget(
                                order: order,
                                department: department,
                                onComplete: () => _completeOrder(order),
                                onDelete: () => _deleteOrder(order),
                              );
                            },
                            childCount: orders.length,
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
  }
}
