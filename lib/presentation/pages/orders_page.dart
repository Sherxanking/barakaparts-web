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
import '../widgets/search_bar_widget.dart';
import '../widgets/filter_chip_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/status_badge_widget.dart';
import '../widgets/animated_list_item.dart';

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
  }

  @override
  void dispose() {
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

    // Parts availability tekshirish
    if (!_orderService.checkPartsAvailability(product.name, quantity)) {
      _showSnackBar('Insufficient parts available', Colors.orange);
      return;
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
        _showSnackBar('Order created successfully', Colors.green);
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

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Create Order Section
                  Card(
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
                            builder: (context, Box<Department> box, _) {
                              final departments = box.values.toList();
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
                            builder: (context, Box<Product> box, _) {
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
                  const SizedBox(height: 16),
                  
                  // Orders List
                  const Text(
                    'Orders List',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Orders list - Real-time updates with swipe refresh
                  ValueListenableBuilder(
                    valueListenable: _boxService.ordersListenable,
                    builder: (context, Box<Order> box, _) {
                      final orders = _getFilteredOrders();

                      if (orders.isEmpty) {
                        return RefreshIndicator(
                          onRefresh: () async {
                            setState(() {});
                            await Future.delayed(const Duration(milliseconds: 500));
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: EmptyStateWidget(
                                icon: Icons.shopping_cart_outlined,
                                title: box.isEmpty 
                                    ? 'No orders yet' 
                                    : 'No orders match your filters',
                                subtitle: box.isEmpty
                                    ? 'Create your first order using the form above'
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
                          shrinkWrap: true,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final department = _departmentService.getDepartmentById(order.departmentId);
                          
                          return AnimatedListItem(
                            delay: index * 50,
                            child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: order.status == 'completed'
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2),
                                child: Icon(
                                  order.status == 'completed' 
                                      ? Icons.check_circle 
                                      : Icons.pending,
                                  color: order.status == 'completed' 
                                      ? Colors.green 
                                      : Colors.orange,
                                ),
                              ),
                              title: Text(
                                order.productName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Department: ${department?.name ?? 'Unknown'}'),
                                  Text('Quantity: ${order.quantity}'),
                                  Text(
                                    'Created: ${order.createdAt.toString().substring(0, 16)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StatusBadgeWidget(status: order.status),
                                  const SizedBox(width: 8),
                                  // Complete button
                                  if (order.status != 'completed')
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Colors.green),
                                      onPressed: () => _completeOrder(order),
                                      tooltip: 'Complete Order',
                                    ),
                                  // Delete button
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteOrder(order),
                                    tooltip: 'Delete Order',
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
