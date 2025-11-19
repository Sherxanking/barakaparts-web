/// DepartmentDetailsPage - Bo'lim tafsilotlari sahifasi
/// 
/// Bu sahifa quyidagi funksiyalarni ta'minlaydi:
/// - Bo'limga mahsulotlar biriktirish
/// - Biriktirilgan mahsulotlarni ko'rish
/// - Mahsulotlarni bo'limdan olib tashlash
/// - Real-time yangilanishlar
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/department_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/part_model.dart';
import '../../data/services/hive_box_service.dart';
import '../../data/services/department_service.dart';
import '../../data/services/product_service.dart';
import '../../data/services/part_service.dart';
import '../widgets/empty_state_widget.dart';

class DepartmentDetailsPage extends StatefulWidget {
  final Department department;
  const DepartmentDetailsPage({super.key, required this.department});

  @override
  State<DepartmentDetailsPage> createState() => _DepartmentDetailsPageState();
}

class _DepartmentDetailsPageState extends State<DepartmentDetailsPage> {
  // Services
  final HiveBoxService _boxService = HiveBoxService();
  final DepartmentService _departmentService = DepartmentService();
  final ProductService _productService = ProductService();
  final PartService _partService = PartService();

  // State
  Product? selectedProduct;
  final TextEditingController _qtyController = TextEditingController();

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  /// Mahsulotni bo'limga biriktirish
  Future<void> _assignProductToDepartment(Product product, int qty) async {
    if (qty <= 0) {
      _showSnackBar('Quantity must be greater than 0', Colors.red);
      return;
    }

    final department = widget.department;

    // Mahsulotni bo'limga qo'shish
    if (!department.productIds.contains(product.id)) {
      department.productIds.add(product.id);
    }

    // Qismlar miqdorini yangilash
    for (var entry in product.parts.entries) {
      final currentQty = department.productParts[entry.key] ?? 0;
      department.productParts[entry.key] = currentQty + (entry.value * qty);
    }

    // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
    final success = await _departmentService.updateDepartment(department);
    if (mounted) {
      if (success) {
        _qtyController.clear();
        selectedProduct = null;
        _showSnackBar('Product assigned successfully', Colors.green);
      } else {
        _showSnackBar('Failed to assign product. Please try again.', Colors.red);
      }
    }
  }

  /// Mahsulotni bo'limdan olib tashlash
  Future<void> _removeProductFromDepartment(Product product) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Product'),
        content: Text('Remove ${product.name} from ${widget.department.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final department = widget.department;
      department.productIds.remove(product.id);

      // Mahsulot qismlarini olib tashlash
      for (var partId in product.parts.keys) {
        department.productParts.remove(partId);
      }

      // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
      final success = await _departmentService.updateDepartment(department);
      if (mounted) {
        if (success) {
          _showSnackBar('Product removed', Colors.orange);
        } else {
          _showSnackBar('Failed to remove product. Please try again.', Colors.red);
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
    final department = widget.department;

    return Scaffold(
      appBar: AppBar(
        title: Text('${department.name} Details'),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Department info card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      department.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Products: ${department.productIds.length}'),
                    Text('Parts assigned: ${department.productParts.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Add product section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Assign Product',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder(
                      valueListenable: _boxService.productsListenable,
                      builder: (context, Box<Product> box, _) {
                        final products = box.values.toList();
                        return DropdownButtonFormField<Product>(
                          value: selectedProduct,
                          decoration: const InputDecoration(
                            labelText: 'Select Product',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory),
                          ),
                          items: products.map((prod) {
                            return DropdownMenuItem(
                              value: prod,
                              child: Text(prod.name),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => selectedProduct = val),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (selectedProduct == null) {
                          _showSnackBar('Please select a product', Colors.red);
                          return;
                        }
                        final qty = int.tryParse(_qtyController.text) ?? 1;
                        _assignProductToDepartment(selectedProduct!, qty);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Assign Product'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Products list
            const Text(
              'Assigned Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Products list - Real-time updates
            // FIX: box.get(id) noto'g'ri - Hive boxda ID key emas, ProductService ishlatish kerak
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _boxService.productsListenable,
                builder: (context, Box<Product> box, _) {
                  // FIX: ProductService.getProductById() ishlatish - to'g'ri ID bo'yicha qidirish
                  final assignedProducts = department.productIds
                      .map((id) => _productService.getProductById(id))
                      .where((p) => p != null)
                      .cast<Product>()
                      .toList();

                  if (assignedProducts.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.inventory_outlined,
                      title: 'No products assigned yet',
                      subtitle: 'Assign products using the form above',
                    );
                  }

                  return ListView.builder(
                    itemCount: assignedProducts.length,
                    itemBuilder: (context, index) {
                      final product = assignedProducts[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
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
                              Text('Parts: ${product.parts.length}'),
                              if (product.parts.isNotEmpty)
                                Text(
                                  product.parts.entries
                                      .map((e) {
                                        final part = _partService.getPartById(e.key);
                                        return '${part?.name ?? e.key}: ${e.value}';
                                      })
                                      .join(', '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeProductFromDepartment(product),
                            tooltip: 'Remove',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
