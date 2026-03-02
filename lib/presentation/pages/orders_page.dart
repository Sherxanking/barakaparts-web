/// OrdersPage - Buyurtmalarni yaratish va boshqarish sahifasi
/// 
/// Bu sahifa quyidagi funksiyalarni ta'minlaydi:
/// - Yangi buyurtma yaratish (Department → Product → Quantity)
/// - Buyurtmalarni ko'rish va boshqarish
/// - Buyurtmalarni qidirish, filtrlash va tartiblash
/// - Buyurtmalarni complete qilish (stock reduction)
/// - Real-time yangilanishlar (ValueListenableBuilder)
import 'dart:async' show StreamSubscription, TimeoutException, Timer;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../core/services/error_handler_service.dart';
import '../../domain/entities/order.dart' as domain;
import '../../domain/entities/user.dart' as domain;
import '../../domain/repositories/order_repository.dart';
import '../../infrastructure/cache/hive_order_cache.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/filter_chip_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/order_item_widget.dart';
import 'order_history_page.dart';
import 'analytics_page.dart';
import '../widgets/skeletons.dart';
import '../../core/utils/toast_service.dart'; // Yangi import
import '../../l10n/app_localizations.dart';
import '../widgets/courier_assignment_dialog.dart';
import '../../core/services/telegram_notification_service.dart';

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
  final TextEditingController _soldToController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  bool _showSoldToError = false;
  bool _showCreateOrderForm = false;

  // Search, Filter, Sort state
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter = 'pending';
  String? _selectedDepartmentFilter;
  SortOption? _selectedSortOption;
  
  // State for initial load only
  bool _isInitialLoading = true;
  
  // Order completion loading state (optimization)
  String? _completingOrderId;
  
  // Search debounce timer
  Timer? _searchDebounceTimer;
  
  // Loading state for courier assignment
  bool _isLoading = false;
  
  /// Check if current user can create orders
  bool get _canCreateOrders {
    final user = AuthStateService().currentUser;
    return user != null && (user.isManager || user.isBoss);
  }
  
  /// Check if current user can complete orders
  bool get _canCompleteOrders {
    final user = AuthStateService().currentUser;
    return user != null && (user.isManager || user.isBoss);
  }
  
  /// Check if current user can delete an order
  bool _canDeleteOrder(domain.Order order) {
    final user = AuthStateService().currentUser;
    if (user == null) return false;
    
    // Hamma "pending" dagi orderni o'chira oladi
    if (order.status == 'pending') {
      return true;
    }
    
    // Pending bo'lmasa, faqat Boss delete qila oladi
    return user.isBoss;
  }
  
  /// Check if current user can edit orders (pending orders only)
  bool get _canEditOrders {
    final user = AuthStateService().currentUser;
    // Faqat Boss va Manager edit qila oladi
    return user != null && (user.isManager || user.isBoss);
  }

  /// Get current user for department filtering (Manager only)
  domain.User? get _currentUser => AuthStateService().currentUser;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // FIX: PartCalculatorService ni ishga tushirish
    _partCalculatorService = PartCalculatorService(_partService);
    // Initialize quantity controller
    _quantityController.text = quantity.toString();
    _quantityController.addListener(_onQuantityChanged);
    
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
    // Cancel debounce timer
    _searchDebounceTimer?.cancel();
    // Cancel listener and subscription
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _soldToController.dispose();
    _quantityController.removeListener(_onQuantityChanged);
    _quantityController.dispose();
    // StreamBuilder handles subscription automatically
    super.dispose();
  }
  
  /// Quantity controller listener - TextField o'zgarganda quantity ni yangilash
  void _onQuantityChanged() {
    final newQuantity = int.tryParse(_quantityController.text);
    if (newQuantity != null && newQuantity > 0) {
      quantity = newQuantity;
    }
  }

  /// Qidiruv o'zgarganda (debounced)
  void _onSearchChanged() {
    // Debounce: 300ms kutish
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// Helper to build a filter chip
  Widget _buildFilterChip(String? status, String label) {
    final isSelected = _selectedStatusFilter == status;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatusFilter = selected ? status : null;
        });
      },
      selectedColor: Theme.of(context).primaryColor,
      backgroundColor: Colors.grey.shade100,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
        ),
      ),
    );
  }

  /// Get filtered orders based on user role
  List<domain.Order> _getFilteredOrders(List<domain.Order> orders) {
    final user = _currentUser;
    
    // Workerlar uchun faqat o'zlariga tayinlangan orderlarni ko'rsatish
    if (user != null && user.isWorker) {
      orders = orders.where((o) => o.workerId == user.id).toList();
    }
    // Manager uchun department filter (faqat o'z department'idagi orders)
    else if (user != null && user.isManager && user.departmentId != null) {
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

  /// Calculate parts shortage for order and notify manager
  void _calculateAndNotifyPartsShortage(String productName, int quantity) {
    _productService.getAllProducts().forEach((product) {
      if (product.name == productName) {
        final shortages = <PartShortage>[];
        
        for (var entry in product.parts.entries) {
          final partId = entry.key;
          final qtyPerProduct = entry.value;
          final requiredQty = qtyPerProduct * quantity;
          
          final part = _partService.getPartById(partId);
          if (part == null) continue;

          // 1. Dashboard-like Stock Alert (if below threshold)
          if (part.quantity <= part.minQuantity) {
            ToastService().showStockAlert(context, part.name, part.quantity);
          }

          // 2. Immediate Shortage for current order
          if (part.quantity < requiredQty) {
            shortages.add(PartShortage(
              partId: partId,
              partName: part.name,
              required: requiredQty,
              available: part.quantity,
            ));
          }
        }

        // If there are shortages, notify manager
        if (shortages.isNotEmpty) {
          _notifyManagerAboutShortage(shortages);
        }
      }
    });
  }

  /// Notify manager about parts shortage via Telegram (simulated)
  void _notifyManagerAboutShortage(List<PartShortage> shortages) {
    final shortageMessages = shortages.map((s) => 
      "${s.partName}: ${s.shortage} dona yetmayapti"
    ).join(", ");
    
    // Simulate sending message to manager via Telegram
    debugPrint('🔔 TELEGRAM NOTIFICATION TO MANAGER: Yetmaydigan qismlar: $shortageMessages');
    
    // In real app, you would call Telegram Bot API here
    // For now, just show in UI
    _showSnackBar(
      'Yetmaydigan qismlar aniqlandi: $shortageMessages', 
      Colors.orange
    );
  }

  /// Notify manager about ready orders via Telegram (simulated)
  void _notifyManagerAboutReadyOrders(int count, String courierName) {
    // Simulate sending message to manager via Telegram
    debugPrint('🔔 TELEGRAM NOTIFICATION TO MANAGER: $count ta tayyor, $courierName olib ketishi mumkin');
    
    // Send notification via Telegram
    TelegramNotificationService.sendReadyOrderNotification(count, courierName);
    
    _showSnackBar(
      '$count ta tayyor, $courierName olib ketishi mumkin', 
      Colors.green
    );
  }

  /// Show courier assignment dialog
  void _showCourierAssignmentDialog(String orderId, int orderQuantity) {
    showDialog(
      context: context,
      builder: (context) => CourierAssignmentDialog(
        orderId: orderId,
        orderQuantity: orderQuantity,
        onAssign: (courierId, quantity) {
          _assignCourierToOrder(orderId, courierId, quantity);
        },
      ),
    );
  }

  /// Assign courier to order
  Future<void> _assignCourierToOrder(String orderId, String courierId, int quantity) async {
    setState(() {
      _isLoading = true; // Using existing _isLoading state
    });

    try {
      final success = await _orderService.assignCourierToOrder(orderId, courierId, quantity);
      
      if (success) {
        // Find the courier name
        // Load user to get courier name
        final userRepository = ServiceLocator.instance.userRepository;
        final result = await userRepository.getUserById(courierId);
        String courierName = 'Courier';
        
        result.fold(
          (failure) {
            courierName = 'Courier';
          },
          (user) {
            courierName = user?.name ?? 'Courier';
          },
        );
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('\$quantity ta \$courierName ga tayinlandi'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Reload orders
          // Data will be reloaded by the stream automatically
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Courier tayinlashda xatolik yuz berdi'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: \$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Show analytics for courier assignments
  void _showCourierAnalytics() {
    final analytics = _orderService.getCourierAnalytics();
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Courier Analytics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: analytics.isEmpty
                      ? const Center(child: Text('No courier analytics data'))
                      : ListView.builder(
                          itemCount: analytics.length,
                          itemBuilder: (context, index) {
                            final entry = analytics.entries.elementAt(index);
                            return ListTile(
                              title: Text(entry.key),
                              subtitle: Text('\${entry.value} items taken'),
                              trailing: const Icon(Icons.check_circle, color: Colors.green),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Yangi order yaratish funksiyasi
  Future<void> _createOrder() async {
    // Validatsiya
    if (selectedDepartmentId == null || selectedProductId == null) {
      _showSnackBar(AppLocalizations.of(context)?.translate('pleaseSelectDepartmentAndProduct') ?? 'Please select a department and product', Colors.red);
      return;
    }

    // SoldTo majburiy tekshirish
    if (_soldToController.text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _showSoldToError = true;
        });
      }
      _showSnackBar('Kim olib ketganini kiriting', Colors.red);
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
    final soldTo = _soldToController.text.trim(); // Endi majburiy, null bo'lmaydi

    final domainOrder = domain.Order(
      id: const Uuid().v4(),
      productId: product.id,
      productName: product.name,
      departmentId: department.id,
      quantity: quantity,
      status: 'pending',
      soldTo: soldTo.isEmpty ? null : soldTo, // Domain'da nullable, lekin UI'da majburiy
      partsRequired: Map<String, int>.from(product.parts), // Order yaratilgan vaqtidagi part miqdorlari (snapshot) - model'da 'parts' nomi bilan
      createdAt: DateTime.now(),
    );

    // Use repository to create order
    final result = await _orderRepository.createOrder(domainOrder);
    
    if (mounted) {
      result.fold(
        (failure) {
          _showSnackBar('Failed to create order: ${ErrorHandlerService.instance.getErrorMessage(failure)}', Colors.red);
        },
        (createdOrder) {
          // Formni tozalash
          setState(() {
            selectedDepartmentId = null;
            selectedProductId = null;
            quantity = 1;
            _quantityController.text = '1';
            _soldToController.clear();
            _showSoldToError = false;
          });
          
          // Hisoblash va xabarnoma yuborish
          _calculateAndNotifyPartsShortage(product.name, quantity);
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
            _showSnackBar('Failed to complete order: ${ErrorHandlerService.instance.getErrorMessage(failure)}', Colors.red);
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

  /// Pending order uchun qismlar ro'yxatini tahrirlash
  Future<Map<String, int>?> _showOrderPartsDialog(Map<String, int> currentParts) async {
    final allParts = _partService.getAllParts();
    final tempSelectedParts = Map<String, int>.from(currentParts);
    final Map<String, TextEditingController> controllers = {};

    for (final part in allParts) {
      final qty = tempSelectedParts[part.id] ?? 0;
      controllers[part.id] = TextEditingController(
        text: qty > 0 ? qty.toString() : '',
      );
    }

    return showDialog<Map<String, int>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Parts'),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          if (qty > 0)
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: controllers[part.id],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  final newQty = int.tryParse(val);
                                  if (newQty != null && newQty > 0) {
                                    setDialogState(() {
                                      tempSelectedParts[part.id] = newQty;
                                    });
                                  } else if (val.isEmpty) {
                                    setDialogState(() {
                                      tempSelectedParts[part.id] = 0;
                                    });
                                  } else {
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
              tempSelectedParts.removeWhere((key, value) => value <= 0);
              Navigator.pop(context, tempSelectedParts);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Buyurtmani tahrirlash (pending orderlar uchun)
  /// Repository pattern - works for both web and mobile
  Future<void> _editOrder(domain.Order order) async {
    // Form state'ni to'ldirish
    setState(() {
      selectedDepartmentId = order.departmentId;
      selectedProductId = order.productId;
      quantity = order.quantity;
      _soldToController.text = order.soldTo ?? '';
    });

    // Parts override (per order)
    Map<String, int> tempParts = Map.from(order.partsRequired ?? {});
    
    // Dialog ko'rsatish
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)?.translate('editOrder') ?? 'Edit Order'),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Department dropdown
                  ValueListenableBuilder(
                    valueListenable: _boxService.departmentsListenable,
                    builder: (context, Box<Department> deptBox, _) {
                      final departments = deptBox.values.toList();
                      return DropdownButtonFormField<String>(
                        value: selectedDepartmentId,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.translate('selectDepartment') ?? 'Select Department',
                          hintText: 'Bo\'limni tanlang',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.business),
                        ),
                        items: departments.isEmpty
                            ? [
                                DropdownMenuItem(
                                  value: null,
                                  enabled: false,
                                  child: Text(
                                    'Bo\'limlar mavjud emas',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ),
                              ]
                            : [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(
                                    'Bo\'limni tanlang',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ),
                                ...departments.map((dept) {
                                  return DropdownMenuItem(
                                    value: dept.id,
                                    child: Text(dept.name),
                                  );
                                }),
                              ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedDepartmentId = value;
                            selectedProductId = null; // Reset product when department changes
                            tempParts = {};
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Product dropdown
                  if (selectedDepartmentId != null)
                    ValueListenableBuilder(
                      valueListenable: _boxService.productsListenable,
                      builder: (context, Box<Product> productBox, _) {
                        final products = productBox.values
                            .where((p) => p.departmentId == selectedDepartmentId)
                            .toList();
                        return DropdownButtonFormField<String>(
                          value: selectedProductId,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.translate('selectProduct') ?? 'Select Product',
                            hintText: 'Mahsulotni tanlang',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.inventory),
                          ),
                          items: products.isEmpty
                              ? [
                                  DropdownMenuItem(
                                    value: null,
                                    enabled: false,
                                    child: Text(
                                      'Mahsulotlar mavjud emas',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                ]
                              : [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'Mahsulotni tanlang',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                  ...products.map((product) {
                                    return DropdownMenuItem<String>(
                                      value: product.id,
                                      child: Text(product.name),
                                    );
                                  }),
                                ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedProductId = value;
                              final product = value != null
                                  ? _productService.getProductById(value)
                                  : null;
                              tempParts = product != null
                                  ? Map<String, int>.from(product.parts)
                                  : {};
                            });
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  
                  // Parts override (optional edit)
                  if (selectedProductId != null) ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        final updated = await _showOrderPartsDialog(tempParts);
                        if (updated != null) {
                          setDialogState(() {
                            tempParts = updated;
                          });
                        }
                      },
                      icon: const Icon(Icons.build_circle),
                      label: Text(
                        tempParts.isEmpty
                            ? 'Add Parts'
                            : 'Edit Parts (${tempParts.length})',
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Quantity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.translate('quantity') ?? 'Quantity',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          if (quantity > 1) {
                            setDialogState(() {
                              quantity--;
                              _quantityController.text = quantity.toString();
                            });
                          }
                        },
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            final newQuantity = int.tryParse(value);
                            if (newQuantity != null && newQuantity > 0) {
                              setDialogState(() {
                                quantity = newQuantity;
                                _quantityController.text = quantity.toString();
                              });
                            } else if (value.isEmpty) {
                              // Allow empty during typing
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setDialogState(() {
                            quantity++;
                            _quantityController.text = quantity.toString();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Recipient input (Majburiy)
                  TextField(
                    controller: _soldToController,
                    decoration: InputDecoration(
                      labelText: 'Kim olib ketdi *',
                      hintText: 'Masalan: Ahmad, Mijoz, Usta, va hokazo',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                      helperText: 'Buyurtmani kim olib ketganini kiriting (Majburiy)',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedDepartmentId == null || selectedProductId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)?.translate('pleaseSelectDepartmentAndProduct') ?? 'Please select a department and product'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  // SoldTo majburiy tekshirish
                  if (_soldToController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kimga sotilganini kiriting'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  if (tempParts.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kamida bitta qism tanlang'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context, {
                    'departmentId': selectedDepartmentId,
                    'productId': selectedProductId,
                    'quantity': quantity,
                    'soldTo': _soldToController.text.trim(),
                    'partsRequired': tempParts,
                  });
                },
                child: Text(AppLocalizations.of(context)?.translate('save') ?? 'Save'),
              ),
            ],
          );
        },
      ),
    );
    
    if (result != null && mounted) {
      // Get product name
      final product = _productService.getProductById(result['productId'] as String);
      if (product == null) {
        _showSnackBar('Product not found', Colors.red);
        return;
      }
      
      // Update order
      final updatedOrder = order.copyWith(
        productId: result['productId'] as String,
        productName: product.name,
        departmentId: result['departmentId'] as String,
        quantity: result['quantity'] as int,
        soldTo: result['soldTo'] as String?,
        partsRequired: Map<String, int>.from(
          (result['partsRequired'] as Map?)?.map(
                (key, value) => MapEntry(key.toString(), (value as num).toInt()),
              ) ??
              {},
        ),
        updatedAt: DateTime.now(),
      );
      
      final updateResult = await _orderRepository.updateOrder(updatedOrder);
      
      if (mounted) {
        updateResult.fold(
          (failure) {
            _showSnackBar('Failed to update order: ${ErrorHandlerService.instance.getErrorMessage(failure)}', Colors.red);
          },
          (_) {
            // Formni tozalash
            setState(() {
              selectedDepartmentId = null;
              selectedProductId = null;
              quantity = 1;
              _quantityController.text = '1';
              _soldToController.clear();
            });
            _showSnackBar(AppLocalizations.of(context)?.translate('orderUpdated') ?? 'Order updated successfully', Colors.green);
          },
        );
      }
    } else {
      // Formni tozalash (cancel bo'lsa)
      setState(() {
        selectedDepartmentId = null;
        selectedProductId = null;
        quantity = 1;
        _quantityController.text = '1';
        _soldToController.clear();
      });
    }
  }

  /// Buyurtmani o'chirish
  /// Repository pattern - works for both web and mobile
  Future<void> _deleteOrder(domain.Order order) async {
    // Permission check
    if (!_canDeleteOrder(order)) {
      _showSnackBar('Sizda order o\'chirish huquqi yo\'q. Bajarilgan orderni faqat Boss o\'chira oladi.', Colors.red);
      return;
    }
    
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.translate('deleteOrder') ?? 'Delete Order'),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppLocalizations.of(context)?.translate('deleteOrderConfirm') ?? 'Are you sure you want to delete order for'} ${order.productName}?'),
            if (order.status == 'completed') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Completed order o\'chirilsa, qismlar miqdori qaytariladi.',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          const SizedBox(height: 4),
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
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Use repository to delete order
      final result = await _orderRepository.deleteOrder(order.id);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        result.fold(
          (failure) {
            _showSnackBar('Order o\'chirishda xatolik: ${ErrorHandlerService.instance.getErrorMessage(failure)}', Colors.red);
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)?.translate('partsInsufficient') ?? 'Quyidagi qismlar yetishmayapti:',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Nusxa olish',
                      color: Colors.blue,
                      onPressed: () {
                        final text = shortages.map((s) => '- ${s.partName}: Kam: ${s.shortage} (Bor: ${s.available}, Kerak: ${s.required})').join('\n');
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ro\'yxat nusxalandi!'), backgroundColor: Colors.green),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...shortages.map((shortage) {
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          shortage.partName == 'Unknown Part' ? 'Noma\'lum qism (ID: ${shortage.partId})' : shortage.partName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text('Bor: ${shortage.available}  |  Kerak: ${shortage.required}'),
                        trailing: Text(
                          'Kam: ${shortage.shortage}',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
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
            body: Column(
              children: [
                // UX: Filterlar joyini saqlab qolamizki, ekran sakramasin
                const SizedBox(height: 100), 
                Expanded(
                  child: ListView.builder(
                    itemCount: 5,
                    itemBuilder: (_, __) => const OrderItemSkeleton(),
                  ),
                ),
              ],
            ),
          );
        }
        
        // Handle error state
        if (snapshot.hasError) {
          return Scaffold(
            body: ErrorDisplayWidget(
              error: snapshot.error,
              onRetry: () => setState(() => _isInitialLoading = true),
            ),
          );
        }
        
        // Handle data
        final orders = snapshot.data?.fold(
          (failure) {
            // Show user-friendly error message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final message = ErrorHandlerService.instance.getErrorMessage(failure);
                ErrorHandlerService.instance.showErrorSnackBar(context, message);
              }
            });
            return <domain.Order>[];
          },
          (orders) => orders,
        ) ?? <domain.Order>[];
        
        final filteredOrders = _getFilteredOrders(orders);
        final currentUser = AuthStateService().currentUser;
        final canSeeAnalytics = currentUser?.canSeeAllLogs() ?? false;
        
        return Scaffold(
          body: Column(
            children: [
              // Search va Filter section
              Container(
                padding: const EdgeInsets.all(20),
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    // Action Buttons (Moved from AppBar)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        PopupMenuButton<SortOption>(
                          icon: const Icon(Icons.sort),
                          tooltip: 'Sort',
                          initialValue: _selectedSortOption,
                          onSelected: (option) {
                            setState(() {
                              _selectedSortOption = option;
                            });
                          },
                          itemBuilder: (context) => const [
                            SortOption.dateDesc,
                            SortOption.dateAsc,
                            SortOption.nameAsc,
                            SortOption.nameDesc,
                          ].map((option) {
                            return PopupMenuItem(
                              value: option,
                              child: Text(option.getLabel(context)),
                            );
                          }).toList(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.history),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderHistoryPage(orders: orders),
                              ),
                            );
                          },
                          tooltip: 'Order History',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    SearchBarWidget(
                      controller: _searchController,
                      hintText: 'Search orders...',
                      onChanged: (_) => setState(() {}),
                      onClear: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    // Status Filter Chips
                    // SingleChildScrollView(
                    //   scrollDirection: Axis.horizontal,
                    //   child: Row(
                    //     children: [
                    //       _buildFilterChip(null, 'Hammasi'),
                    //       const SizedBox(width: 8),
                    //       _buildFilterChip('pending', 'Kutilmoqda'),
                    //       const SizedBox(width: 8),
                    //       // _buildFilterChip('in_progress', 'Jarayonda'),
                    //       // const SizedBox(width: 8),
                    //       // _buildFilterChip('partially_completed', 'Qisman'),
                    //       // const SizedBox(width: 8),
                    //       _buildFilterChip('completed', 'Tugallangan'),
                    //       // const SizedBox(width: 8),
                    //       // _buildFilterChip('cancelled', 'Bekor qilingan'),
                    //     ],
                    //   ),
                    // ),
                  ],
                ),
              ),



              // Main content - CustomScrollView + SliverList
              Expanded(
                child: Builder(
                  builder: (context) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() => _isInitialLoading = true);
                        await Future.delayed(const Duration(milliseconds: 500));
                        setState(() => _isInitialLoading = false);
                      },
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          // Create Order Section
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!_showCreateOrderForm)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _showCreateOrderForm = true;
                                        });
                                      },
                                      icon: const Icon(Icons.add),
                                      label: Text(AppLocalizations.of(context)?.translate('createNewOrder') ?? 'Create New Order'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  if (_showCreateOrderForm)
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 600),
                                        child: Card(
                                          elevation: 3,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                  AppLocalizations.of(context)?.translate('createNewOrder') ?? 'Create New Order',
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                
                                                // Department dropdown
                                                ValueListenableBuilder(
                                                  valueListenable: _boxService.departmentsListenable,
                                                  builder: (context, Box<Department> deptBox, _) {
                                                    final departments = deptBox.values.toList();
                                                    return DropdownButtonFormField<String>(
                                                      initialValue: selectedDepartmentId,
                                                      decoration: InputDecoration(
                                                        labelText: AppLocalizations.of(context)?.translate('selectDepartment') ?? 'Select Department',
                                                        hintText: 'Bo\'limni tanlang',
                                                        border: const OutlineInputBorder(),
                                                        prefixIcon: const Icon(Icons.business),
                                                      ),
                                                      items: departments.isEmpty
                                                          ? [
                                                              DropdownMenuItem(
                                                                value: null,
                                                                enabled: false,
                                                                child: Text(
                                                                  'Bo\'limlar mavjud emas',
                                                                  style: TextStyle(color: Colors.grey[600]),
                                                                ),
                                                              ),
                                                            ]
                                                          : [
                                                              DropdownMenuItem<String>(
                                                                value: null,
                                                                child: Text(
                                                                  'Bo\'limni tanlang',
                                                                  style: TextStyle(color: Colors.grey[600]),
                                                                ),
                                                              ),
                                                              ...departments.map((dept) {
                                                                return DropdownMenuItem(
                                                                  value: dept.id,
                                                                  child: Text(dept.name),
                                                                );
                                                              }).toList(),
                                                            ],
                                                      onChanged: (value) {
                                                        setState(() {
                                                          selectedDepartmentId = value;
                                                          selectedProductId = null; // Reset product
                                                        });
                                                      },
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 20),
                                                
                                                // Product dropdown (filtered by department)
                                                ValueListenableBuilder(
                                                  valueListenable: _boxService.productsListenable,
                                                  builder: (context, Box<Product> prodBox, _) {
                                                    final products = selectedDepartmentId != null
                                                        ? _productService.getProductsByDepartment(selectedDepartmentId!)
                                                        : <Product>[];
                                                    
                                                    return DropdownButtonFormField<String>(
                                                      key: ValueKey('product_${selectedDepartmentId}_${selectedProductId}'),
                                                      initialValue: selectedProductId,
                                                      decoration: InputDecoration(
                                                        labelText: AppLocalizations.of(context)?.translate('selectProduct') ?? 'Select Product',
                                                        hintText: 'Mahsulotni tanlang',
                                                        border: const OutlineInputBorder(),
                                                        prefixIcon: const Icon(Icons.inventory),
                                                      ),
                                                      items: selectedDepartmentId == null
                                                          ? [
                                                              DropdownMenuItem(
                                                                value: null,
                                                                enabled: false,
                                                                child: Text(
                                                                  'Avval bo\'limni tanlang',
                                                                  style: TextStyle(color: Colors.grey[600]),
                                                                ),
                                                              ),
                                                            ]
                                                          : products.isEmpty
                                                              ? [
                                                                  DropdownMenuItem(
                                                                    value: null,
                                                                    enabled: false,
                                                                    child: Text(
                                                                      'Bu bo\'limda mahsulotlar yo\'q',
                                                                      style: TextStyle(color: Colors.grey[600]),
                                                                    ),
                                                                  ),
                                                                ]
                                                              : [
                                                                  DropdownMenuItem<String>(
                                                                    value: null,
                                                                    child: Text(
                                                                      'Mahsulotni tanlang',
                                                                      style: TextStyle(color: Colors.grey[600]),
                                                                    ),
                                                                  ),
                                                                  ...products.map((product) {
                                                                    return DropdownMenuItem(
                                                                      value: product.id,
                                                                      child: Text(product.name),
                                                                    );
                                                                  }).toList(),
                                                                ],
                                                      onChanged: selectedDepartmentId != null && products.isNotEmpty
                                                          ? (value) {
                                                              setState(() {
                                                                selectedProductId = value;
                                                              });
                                                            }
                                                          : null,
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 12),
                                                
                                                // Quantity selector
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text('${AppLocalizations.of(context)?.translate('quantity') ?? 'Quantity'}: ', style: const TextStyle(fontSize: 16)),
                                                    IconButton(
                                                      icon: const Icon(Icons.remove_circle_outline),
                                                      onPressed: () {
                                                        if (quantity > 1) {
                                                          setState(() {
                                                            quantity--;
                                                            _quantityController.text = quantity.toString();
                                                          });
                                                        }
                                                      },
                                                    ),
                                                    SizedBox(
                                                      width: 80,
                                                      child: TextField(
                                                        controller: _quantityController,
                                                        keyboardType: TextInputType.number,
                                                        textAlign: TextAlign.center,
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        decoration: const InputDecoration(
                                                          isDense: true,
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                          border: OutlineInputBorder(),
                                                        ),
                                                        onChanged: (value) {
                                                          final newQuantity = int.tryParse(value);
                                                          if (newQuantity != null && newQuantity > 0) {
                                                            setState(() => quantity = newQuantity);
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.add_circle_outline),
                                                      onPressed: () {
                                                        setState(() {
                                                          quantity++;
                                                          _quantityController.text = quantity.toString();
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                
                                                // Recipient input (Majburiy)
                                                TextField(
                                                  controller: _soldToController,
                                                  decoration: InputDecoration(
                                                    labelText: 'Kim olib ketdi *',
                                                    hintText: 'Masalan: Ahmad, Mijoz, Usta, va hokazo',
                                                    border: const OutlineInputBorder(),
                                                    prefixIcon: const Icon(Icons.person),
                                                    helperText: 'Buyurtmani kim olib ketganini kiriting (Majburiy)',
                                                    errorText: _showSoldToError && _soldToController.text.trim().isEmpty
                                                        ? 'Kim olib ketganini kiriting'
                                                        : null,
                                                  ),
                                                  textCapitalization: TextCapitalization.words,
                                                  onChanged: (value) {
                                                    if (_showSoldToError && value.trim().isNotEmpty) {
                                                      setState(() {
                                                        _showSoldToError = false;
                                                      });
                                                    }
                                                  },
                                                ),
                                                const SizedBox(height: 16),
                                                
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            _showCreateOrderForm = false;
                                                            selectedDepartmentId = null;
                                                            selectedProductId = null;
                                                            quantity = 1;
                                                            _quantityController.text = '1';
                                                            _soldToController.clear();
                                                            _showSoldToError = false;
                                                          });
                                                        },
                                                        child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      flex: 2,
                                                      child: ElevatedButton.icon(
                                                        onPressed: _canCreateOrders ? () {
                                                          _createOrder();
                                                          if (!_showSoldToError && selectedDepartmentId != null && selectedProductId != null) {
                                                            setState(() => _showCreateOrderForm = false);
                                                          }
                                                        } : null,
                                                        icon: const Icon(Icons.add_shopping_cart),
                                                        label: Text(AppLocalizations.of(context)?.translate('createOrder') ?? 'Create Order'),
                                                        style: ElevatedButton.styleFrom(
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Orders List Header
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                              child: Text(
                                AppLocalizations.of(context)?.translate('ordersList') ?? 'Orders List',
                                style: const TextStyle(
                                  fontSize: 22,
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
                                    ? 'Hali buyurtmalar yo\'q' 
                                    : 'Filtrga mos buyurtma topilmadi',
                                subtitle: orders.isEmpty
                                    ? 'Yuqoridagi tugma orqali birinchi buyurtmani yarating'
                                    : 'Qidiruv shartlarini o\'zgartirib ko\'ring',
                                actionButton: orders.isEmpty ? ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showCreateOrderForm = true;
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Birinchi buyurtmani qo\'shish'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ) : null,
                              ),
                            )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final domainOrder = filteredOrders[index];
                                  final department = _departmentService.getDepartmentById(domainOrder.departmentId);
                                  final dataOrder = _orderService.getOrderById(domainOrder.id);
                                  
                                  return OrderItemWidget(
                                    order: domainOrder,
                                    dataOrder: dataOrder,
                                    department: department,
                                    onComplete: _canCompleteOrders ? () => _completeOrder(domainOrder) : null,
                                    onEdit: (['pending', 'in_progress', 'partially_completed'].contains(domainOrder.status) && _canEditOrders) 
                                        ? () => _editOrder(domainOrder) 
                                        : null,
                                    onDelete: _canDeleteOrder(domainOrder) ? () => _deleteOrder(domainOrder) : null,
                                    isCompleting: _completingOrderId == domainOrder.id,
                                    onCourierAssign: () => _showCourierAssignmentDialog(domainOrder.id, domainOrder.quantity),
                                    isCourierMode: (_currentUser?.isManager == true || _currentUser?.isBoss == true),
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
