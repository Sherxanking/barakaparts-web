/// ProductEditPage - Mahsulotni tahrirlash sahifasi
/// 
/// Bu sahifa foydalanuvchiga mahsulotni tahrirlash imkonini beradi:
/// - Mahsulot nomini o'zgartirish
/// - Bo'limni o'zgartirish
/// - Mahsulotga qismlar qo'shish/olib tashlash
/// - Qismlar miqdorini o'zgartirish
/// 
/// Barcha o'zgarishlar Hive'ga saqlanadi va mahsulot real-time yangilanadi.
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/product_model.dart';
import '../../data/models/department_model.dart';
import '../../data/models/part_model.dart';
import '../../data/services/hive_box_service.dart';
import '../../data/services/product_service.dart';
import '../../data/services/department_service.dart';
import '../../data/services/part_service.dart';
import '../../l10n/app_localizations.dart';

class ProductEditPage extends StatefulWidget {
  final Product product;

  const ProductEditPage({
    super.key,
    required this.product,
  });

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  // Xizmatlar (Services)
  final HiveBoxService _boxService = HiveBoxService();
  final ProductService _productService = ProductService();
  final DepartmentService _departmentService = DepartmentService();
  final PartService _partService = PartService();

  // Controllerlar (Input maydonlari uchun)
  late TextEditingController _nameController;
  
  // Holat (State)
  String? _selectedDepartmentId;
  Map<String, int> _productParts = {};

  @override
  void initState() {
    super.initState();
    // Joriy mahsulot ma'lumotlari bilan controllerlarni ishga tushirish
    _nameController = TextEditingController(text: widget.product.name);
    _selectedDepartmentId = widget.product.departmentId;
    _productParts = Map<String, int>.from(widget.product.parts);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Mahsulot o'zgarishlarini Hive'ga saqlash
  /// 
  /// Bu metod mahsulot nomi, bo'limi va qismlarini tekshirib,
  /// barcha o'zgarishlarni Hive'ga saqlaydi.
  Future<void> _saveProduct() async {
    final l10n = AppLocalizations.of(context);
    
    // Tekshirish (Validation)
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar(l10n?.translate('enterProductName') ?? 'Please enter a product name', Colors.red);
      return;
    }

    if (_selectedDepartmentId == null) {
      _showSnackBar(l10n?.translate('pleaseSelectDepartment') ?? 'Please select a department', Colors.red);
      return;
    }

    // Mahsulotni yangilash
    widget.product.name = _nameController.text.trim();
    
    // Bo'lim o'zgarishini boshqarish
    if (widget.product.departmentId != _selectedDepartmentId) {
      // Eski bo'limdan olib tashlash
      await _departmentService.removeProductFromDepartment(
        widget.product.departmentId,
        widget.product.id,
      );
      // Yangi bo'limga qo'shish
      widget.product.departmentId = _selectedDepartmentId!;
      await _departmentService.assignProductToDepartment(
        _selectedDepartmentId!,
        widget.product.id,
      );
    }
    
    // Qismlarni yangilash
    widget.product.parts = Map<String, int>.from(_productParts);
    
    // Hive'ga saqlash
    // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
    final success = await _productService.updateProduct(widget.product);
    
    if (mounted) {
      if (success) {
        _showSnackBar(
          l10n?.translate('productUpdated') ?? 'Product updated successfully',
          Colors.green,
        );
        Navigator.pop(context, true); // Muvaffaqiyatni bildirish uchun true qaytarish
      } else {
        _showSnackBar(
          l10n?.translate('productUpdateFailed') ?? 'Failed to update product. Please try again.',
          Colors.red,
        );
      }
    }
  }

  /// Qismlar tanlash dialogini ko'rsatish
  /// 
  /// Bu metod foydalanuvchiga mahsulotga qismlar qo'shish yoki o'zgartirish imkonini beradi.
  /// Har bir qism uchun miqdor kiritish maydoni mavjud.
  void _showPartsDialog() {
    final l10n = AppLocalizations.of(context);
    final allParts = _partService.getAllParts();
    
    if (allParts.isEmpty) {
      _showSnackBar(
        l10n?.translate('noPartsAvailable') ?? 'No parts available. Please add parts first.',
        Colors.orange,
      );
      return;
    }
    
    Map<String, int> tempParts = Map<String, int>.from(_productParts);
    // Har bir qism uchun miqdor kiritish maydoni controllerlari
    final Map<String, TextEditingController> controllers = {};

    // Barcha qismlar uchun controllerlarni yaratish
    for (final part in allParts) {
      final qty = tempParts[part.id] ?? 0;
      controllers[part.id] = TextEditingController(
        text: qty > 0 ? qty.toString() : '',
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n?.translate('selectParts') ?? 'Select Parts'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: allParts.map((part) {
                      final qty = tempParts[part.id] ?? 0;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(part.name),
                          subtitle: Text('${l10n?.translate('quantity') ?? 'Quantity'}: ${part.quantity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Qismni tanlash checkbox
                              Checkbox(
                                value: qty > 0,
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      tempParts[part.id] = 1;
                                      // FIX: disposed check olib tashlandi - try-catch ishlatish
                                      try {
                                        if (controllers[part.id] != null) {
                                          controllers[part.id]!.text = '1';
                                        }
                                      } catch (e) {
                                        // Controller allaqachon dispose qilingan
                                      }
                                    } else {
                                      tempParts.remove(part.id);
                                      try {
                                        if (controllers[part.id] != null) {
                                          controllers[part.id]!.text = '';
                                        }
                                      } catch (e) {
                                        // Controller allaqachon dispose qilingan
                                      }
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
                                    decoration: InputDecoration(
                                      labelText: l10n?.translate('quantity') ?? 'Qty',
                                      isDense: true,
                                    ),
                                    controller: controllers[part.id],
                                    onChanged: (val) {
                                      // FIX: disposed check olib tashlandi - try-catch ishlatish
                                      try {
                                        if (controllers[part.id] == null) return;
                                        
                                        final newQty = int.tryParse(val);
                                        if (newQty != null && newQty > 0) {
                                          tempParts[part.id] = newQty;
                                        } else if (val.isEmpty) {
                                          // Yozish paytida bo'sh qoldirishga ruxsat berish
                                          tempParts.remove(part.id);
                                        } else {
                                          // Noto'g'ri kiritilgan qiymat, oldingi qiymatga qaytarish
                                          final prevQty = tempParts[part.id] ?? 1;
                                          controllers[part.id]!.text = prevQty.toString();
                                          tempParts[part.id] = prevQty;
                                        }
                                      } catch (e) {
                                        // Controller allaqachon dispose qilingan yoki xatolik
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
              actions: [
                TextButton(
                  onPressed: () {
                    // Controllerlarni tozalash
                    // FIX: disposed check olib tashlandi - faqat try-catch ishlatish
                    for (final controller in controllers.values) {
                      try {
                        controller.dispose();
                      } catch (e) {
                        // Controller allaqachon dispose qilingan yoki xatolik
                      }
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: Text(l10n?.cancel ?? 'Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    // Ma'lumotlarni saqlash
                    if (mounted) {
                      setState(() {
                        _productParts = Map<String, int>.from(tempParts);
                      });
                    }
                    // Controllerlarni tozalash
                    // FIX: disposed check olib tashlandi - faqat try-catch ishlatish
                    for (final controller in controllers.values) {
                      try {
                        controller.dispose();
                      } catch (e) {
                        // Controller allaqachon dispose qilingan yoki xatolik
                      }
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: Text(l10n?.save ?? 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Mahsulotdan qismni olib tashlash
  /// 
  /// [partId] - Olib tashlanadigan qismning ID si
  void _removePart(String partId) {
    setState(() {
      _productParts.remove(partId);
    });
  }

  /// Qism miqdorini yangilash
  /// 
  /// [partId] - Yangilanadigan qismning ID si
  /// [quantity] - Yangi miqdor
  /// Agar miqdor 0 yoki manfiy bo'lsa, qism olib tashlanadi
  void _updatePartQuantity(String partId, int quantity) {
    if (quantity <= 0) {
      _removePart(partId);
    } else {
      setState(() {
        _productParts[partId] = quantity;
      });
    }
  }

  /// Xabar ko'rsatish (SnackBar)
  /// 
  /// [message] - Ko'rsatiladigan xabar matni
  /// [color] - Xabar fon rangi
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.translate('editProduct') ?? 'Edit Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProduct,
            tooltip: l10n?.save ?? 'Save',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mahsulot nomi
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n?.translate('productName') ?? 'Product Name',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.label),
              ),
              autofocus: false,
            ),
            const SizedBox(height: 24),
            
            // Bo'lim tanlash
            ValueListenableBuilder(
              valueListenable: _boxService.departmentsListenable,
              builder: (context, Box<Department> deptBox, _) {
                final departments = deptBox.values.toList();
                return DropdownButtonFormField<String>(
                  value: _selectedDepartmentId,
                  decoration: InputDecoration(
                    labelText: l10n?.translate('selectDepartment') ?? 'Select Department',
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
                      _selectedDepartmentId = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            
            // Qismlar bo'limi
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n?.translate('parts') ?? 'Parts',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showPartsDialog,
                          icon: const Icon(Icons.add),
                          label: Text(l10n?.translate('selectParts') ?? 'Select Parts'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_productParts.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n?.translate('selectParts') ?? 'No parts selected. Tap "Select Parts" to add.',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ..._productParts.entries.map((entry) {
                        final part = _partService.getPartById(entry.key);
                        if (part == null) return const SizedBox.shrink();
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.build),
                            title: Text(part.name),
                            subtitle: Text('${l10n?.translate('quantity') ?? 'Quantity'}: ${entry.value}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Miqdor boshqarish tugmalari
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () {
                                    _updatePartQuantity(entry.key, entry.value - 1);
                                  },
                                ),
                                Text(
                                  '${entry.value}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    _updatePartQuantity(entry.key, entry.value + 1);
                                  },
                                ),
                                // O'chirish tugmasi
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removePart(entry.key),
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
          ],
        ),
      ),
    );
  }
}

