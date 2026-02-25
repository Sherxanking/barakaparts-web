import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/department_model.dart';
import '../../data/models/product_model.dart';
import '../../data/services/department_service.dart';
import '../../data/services/product_service.dart';
import '../../data/services/order_service.dart';
import '../../data/services/part_calculator_service.dart';
import '../../data/services/part_service.dart';
import '../../data/services/hive_box_service.dart';
import '../../core/services/auth_state_service.dart';
import '../../core/di/service_locator.dart';
import '../widgets/order_parts_list_widget.dart';
import '../../l10n/app_localizations.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final DepartmentService _departmentService = DepartmentService();
  final ProductService _productService = ProductService();
  final PartService _partService = PartService();
  final OrderService _orderService = OrderService();
  final PartCalculatorService _partCalculatorService = PartCalculatorService(PartService());

  String? _selectedDepartmentId;
  String? _selectedProductId;
  int _quantity = 1;
  final TextEditingController _soldToController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _showSoldToError = false;
  bool _isLoading = false;
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _quantityController.text = _quantity.toString();
    _quantityController.addListener(_onQuantityChanged);
    // Sahifa ochilganda Supabase'dan yuklash
    Future.microtask(() => _loadData());
  }

  /// Supabase'dan departments va products yuklab Hive'ga yozish
  Future<void> _loadData() async {
    if (_isLoadingData) return;
    if (mounted) setState(() => _isLoadingData = true);
    try {
      final deptRepo = ServiceLocator.instance.departmentRepository;
      final productRepo = ServiceLocator.instance.productRepository;
      final boxService = HiveBoxService();
      final deptBox = boxService.departmentsBox;
      final productBox = boxService.productsBox;

      // Departments yuklash
      final deptResult = await deptRepo.getAllDepartments();
      await deptResult.fold(
        (failure) async {
          debugPrint('❌ Departments yuklanmadi: ${failure.message}');
        },
        (departments) async {
          if (departments.isNotEmpty) {
            final existingMap = <String, Department>{};
            for (final d in deptBox.values) {
              existingMap[d.id] = d;
            }
            await deptBox.clear();
            for (final d in departments) {
              final existing = existingMap[d.id];
              await deptBox.add(Department(
                id: d.id,
                name: d.name,
                productIds: existing?.productIds ?? [],
                productParts: existing?.productParts ?? {},
              ));
            }
            debugPrint('✅ ${departments.length} ta department yuklandi');
          }
        },
      );

      // Products yuklash
      final productResult = await productRepo.getAllProducts();
      await productResult.fold(
        (failure) async {
          debugPrint('❌ Products yuklanmadi: ${failure.message}');
        },
        (products) async {
          if (products.isNotEmpty) {
            await productBox.clear();
            for (final p in products) {
              await productBox.add(Product(
                id: p.id,
                name: p.name,
                departmentId: p.departmentId,
                parts: p.partsRequired,
              ));
            }
            debugPrint('✅ ${products.length} ta product yuklandi');
          }
        },
      );
    } catch (e) {
      debugPrint('❌ _loadData xatosi: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  void dispose() {
    _quantityController.removeListener(_onQuantityChanged);
    _quantityController.dispose();
    _soldToController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onQuantityChanged() {
    final newQuantity = int.tryParse(_quantityController.text);
    if (newQuantity != null && newQuantity > 0) {
      setState(() {
        _quantity = newQuantity;
      });
    }
  }

  Future<void> _createOrder() async {
    if (_selectedDepartmentId == null || _selectedProductId == null) {
      _showSnackBar('Please select a department and product', Colors.red);
      return;
    }

    if (_soldToController.text.trim().isEmpty) {
      setState(() {
        _showSoldToError = true;
      });
      _showSnackBar('Please enter who took it', Colors.red);
      return;
    }

    final department = _departmentService.getDepartmentById(_selectedDepartmentId!);
    final product = _productService.getProductById(_selectedProductId!);

    if (department == null || product == null) {
      _showSnackBar('Selected department or product not found', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final orderId = const Uuid().v4();
      final success = await _orderService.createOrderWithPartsSnapshot(
        id: orderId,
        departmentId: department.id,
        productName: product.name,
        quantity: _quantity,
        soldTo: _soldToController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (success) {
        // Reset form
        setState(() {
          _selectedDepartmentId = null;
          _selectedProductId = null;
          _quantity = 1;
          _soldToController.clear();
          _notesController.clear();
          _showSoldToError = false;
        });

        _showSnackBar('Order created successfully in pending state', Colors.green);
      } else {
        _showSnackBar('Failed to create order', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error creating order: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
    final departments = _departmentService.getAllDepartments();
    final products = _selectedDepartmentId != null
        ? _productService.getProductsByDepartment(_selectedDepartmentId!)
        : <Product>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Order'),
        elevation: 2,
        actions: [
          _isLoadingData
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yangilash',
                  onPressed: _loadData,
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Department Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Department',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedDepartmentId,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                      ),
                      items: departments.isEmpty
                          ? [
                              const DropdownMenuItem(
                                value: null,
                                enabled: false,
                                child: Text('No departments available'),
                              ),
                            ]
                          : [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Select a department'),
                              ),
                              ...departments.map((dept) {
                                return DropdownMenuItem<String>(
                                  value: dept.id,
                                  child: Text(dept.name),
                                );
                              }),
                            ],
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartmentId = value;
                          _selectedProductId = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Product Selection
            if (_selectedDepartmentId != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Product',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedProductId,
                        decoration: const InputDecoration(
                          labelText: 'Product',
                          border: OutlineInputBorder(),
                        ),
                        items: products.isEmpty
                            ? [
                                const DropdownMenuItem(
                                  value: null,
                                  enabled: false,
                                  child: Text('No products in this department'),
                                ),
                              ]
                            : [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Select a product'),
                                ),
                                ...products.map((product) {
                                  return DropdownMenuItem<String>(
                                    value: product.id,
                                    child: Text(product.name),
                                  );
                                }),
                              ],
                        onChanged: (value) {
                          setState(() {
                            _selectedProductId = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Quantity Selection
            if (_selectedProductId != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Quantity',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _quantity > 1
                                ? () {
                                    setState(() {
                                      _quantity--;
                                      _quantityController.text = _quantity.toString();
                                    });
                                  }
                                : null,
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
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setState(() {
                                _quantity++;
                                _quantityController.text = _quantity.toString();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selected: $_quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Who took it and Notes
            if (_selectedProductId != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Who took it?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _soldToController,
                        decoration: InputDecoration(
                          labelText: 'Who took it?',
                          hintText: 'Enter name or description',
                          border: const OutlineInputBorder(),
                          errorText: _showSoldToError && _soldToController.text.trim().isEmpty
                              ? 'This field is required'
                              : null,
                        ),
                        onChanged: (value) {
                          if (_showSoldToError && value.trim().isNotEmpty) {
                            setState(() {
                              _showSoldToError = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Optional Notes',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Any additional information',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Show parts required if product is selected
            if (_selectedProductId != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parts Required',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _selectedProductId != null
                          ? FutureBuilder<Product?>(
                              future: Future.value(_productService.getProductById(_selectedProductId!)),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  final product = snapshot.data!;
                                  return OrderPartsListWidget(
                                    parts: product.parts,
                                    orderQuantity: _quantity,
                                    partService: _partService,
                                  );
                                }
                                return const Text('Loading parts...');
                              },
                            )
                          : const Text('Please select a product first'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Create Order Button
            if (_selectedProductId != null)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _createOrder,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_shopping_cart),
                label: _isLoading
                    ? const Text('Creating...')
                    : const Text('Create Order (Pending)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}