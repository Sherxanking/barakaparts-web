/// PartsPage - Qismlar inventarini boshqarish sahifasi
/// 
/// Bu sahifa quyidagi funksiyalarni ta'minlaydi:
/// - Qismlarni qo'shish, tahrirlash, o'chirish
/// - Qismlar miqdorini boshqarish (oshirish/kamaytirish)
/// - Qidiruv, filtrlash va tartiblash
/// - Low stock ogohlantirishlari
/// - Rasm qo'shish va boshqarish
/// - Real-time yangilanishlar
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/part_model.dart';
import '../../data/services/hive_box_service.dart';
import '../../data/services/part_service.dart';
import '../../data/services/image_service.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/filter_chip_widget.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/image_picker_widget.dart';
import '../../l10n/app_localizations.dart';

class PartsPage extends StatefulWidget {
  const PartsPage({super.key});

  @override
  State<PartsPage> createState() => _PartsPageState();
}

class _PartsPageState extends State<PartsPage> {
  // Services
  final HiveBoxService _boxService = HiveBoxService();
  final PartService _partService = PartService();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _minQuantityController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // State
  SortOption? _selectedSortOption;
  bool _showLowStockOnly = false;
  File? _selectedImage; // Tanlangan rasm (add/edit uchun)
  String? _currentEditImagePath; // Tahrirlash uchun hozirgi rasm yo'li

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
    _quantityController.dispose();
    _minQuantityController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Kam qolgan qismlarni olish (minQuantity dan kam)
  List<PartModel> _getLowStockParts() {
    return _partService.getAllParts().where((part) {
      return part.quantity < part.minQuantity;
    }).toList();
  }

  /// Filtrlangan va tartiblangan partlarni olish
  List<PartModel> _getFilteredParts() {
    List<PartModel> parts = _partService.searchParts(_searchController.text);

    // Low stock filter - minQuantity ga asoslangan
    if (_showLowStockOnly) {
      parts = parts.where((part) => part.quantity < part.minQuantity).toList();
    }

    // Tartiblash
    if (_selectedSortOption != null) {
      final byName = _selectedSortOption == SortOption.nameAsc || 
                     _selectedSortOption == SortOption.nameDesc;
      parts = _partService.sortParts(
        parts,
        byName: byName,
        ascending: _selectedSortOption!.ascending,
      );
    }

    return parts;
  }

  /// Yangi qism qo'shish
  Future<void> _addPart() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a part name', Colors.red);
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 1;
    if (quantity < 0) {
      _showSnackBar('Quantity cannot be negative', Colors.red);
      return;
    }

    final partId = const Uuid().v4();
    String? imagePath;

    // Rasmni saqlash
    if (_selectedImage != null) {
      imagePath = await ImageService.saveImage(_selectedImage!, partId);
    }

    final minQuantity = int.tryParse(_minQuantityController.text) ?? 3;

    final part = PartModel(
      id: partId,
      name: _nameController.text.trim(),
      quantity: quantity,
      status: 'available',
      imagePath: imagePath,
      minQuantity: minQuantity,
    );

    // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
    final success = await _partService.addPart(part);
    if (mounted) {
      if (success) {
        _nameController.clear();
        _quantityController.clear();
        _minQuantityController.clear();
        _selectedImage = null;
        _showSnackBar('Part added successfully', Colors.green);
        Navigator.pop(context);
      } else {
        _showSnackBar('Failed to add part. Please try again.', Colors.red);
      }
    }
  }

  /// Qismni o'chirish
  Future<void> _deletePart(PartModel part) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Part'),
        content: Text('Are you sure you want to delete ${part.name}?'),
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
      final parts = _getFilteredParts();
      final index = parts.indexOf(part);
      
      if (index >= 0) {
        // Rasmni o'chirish
        if (part.imagePath != null) {
          await ImageService.deleteImage(part.imagePath);
        }
        
        // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
        final success = await _partService.deletePart(index);
        if (mounted) {
          if (success) {
            _showSnackBar('Part deleted', Colors.orange);
          } else {
            _showSnackBar('Failed to delete part. Please try again.', Colors.red);
          }
        }
      }
    }
  }

  /// Qismni tahrirlash
  Future<void> _editPart(PartModel part) async {
    _nameController.text = part.name;
    _quantityController.text = part.quantity.toString();
    _minQuantityController.text = part.minQuantity.toString();
    _currentEditImagePath = part.imagePath;
    _selectedImage = null;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Part'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rasm picker
              ImagePickerWidget(
                currentImagePath: _currentEditImagePath,
                onImagePicked: (imageFile) {
                  setState(() {
                    _selectedImage = imageFile;
                    if (imageFile == null) {
                      _currentEditImagePath = null;
                    }
                  });
                },
                onImageDeleted: () {
                  setState(() {
                    _currentEditImagePath = null;
                    _selectedImage = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Part Name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _minQuantityController,
                decoration: const InputDecoration(
                  labelText: 'Min Quantity (Alert Threshold)',
                  border: OutlineInputBorder(),
                  helperText: 'Alert when quantity falls below this',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _nameController.clear();
              _quantityController.clear();
              _minQuantityController.clear();
              _selectedImage = null;
              _currentEditImagePath = null;
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_nameController.text.trim().isEmpty) {
                _showSnackBar('Please enter a part name', Colors.red);
                return;
              }

              // Eski rasmini o'chirish (agar yangi rasm tanlangan bo'lsa)
              if (_selectedImage != null && part.imagePath != null) {
                await ImageService.deleteImage(part.imagePath);
              }

              // Yangi rasmini saqlash
              String? newImagePath = part.imagePath;
              if (_selectedImage != null) {
                newImagePath = await ImageService.saveImage(_selectedImage!, part.id);
              } else if (_currentEditImagePath == null && part.imagePath != null) {
                // Rasm o'chirilgan bo'lsa
                await ImageService.deleteImage(part.imagePath);
                newImagePath = null;
              }

              part.name = _nameController.text.trim();
              final qty = int.tryParse(_quantityController.text) ?? part.quantity;
              part.quantity = qty < 0 ? 0 : qty;
              final minQty = int.tryParse(_minQuantityController.text) ?? part.minQuantity;
              part.minQuantity = minQty < 0 ? 0 : minQty;
              part.imagePath = newImagePath;
              
              // FIX: Service endi bool qaytaradi - muvaffaqiyatni tekshirish
              final success = await _partService.updatePart(part);
              if (mounted) {
                if (success) {
                  _nameController.clear();
                  _quantityController.clear();
                  _minQuantityController.clear();
                  _selectedImage = null;
                  _currentEditImagePath = null;
                  Navigator.pop(context);
                  _showSnackBar('Part updated', Colors.green);
                } else {
                  _showSnackBar('Failed to update part. Please try again.', Colors.red);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }


  /// Rasm tanlash va yangilash
  Future<void> _pickAndUpdateImage(PartModel part) async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.camera_alt, size: 32, color: Colors.blue),
              title: const Text('Camera', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Take a new photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.photo_library, size: 32, color: Colors.green),
              title: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    
    if (source != null) {
      try {
        final pickedFile = await picker.pickImage(source: source);
        if (pickedFile != null) {
          // Eski rasmini o'chirish
          if (part.imagePath != null) {
            await ImageService.deleteImage(part.imagePath);
          }
          // Yangi rasmini saqlash
          final newImagePath = await ImageService.saveImage(
            File(pickedFile.path),
            part.id,
          );
          part.imagePath = newImagePath;
          // FIX: Service endi bool qaytaradi
          final success = await _partService.updatePart(part);
          if (mounted) {
            if (success) {
              _showSnackBar('Image updated', Colors.green);
            } else {
              _showSnackBar('Failed to update image. Please try again.', Colors.red);
            }
          }
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error: ${e.toString()}', Colors.red);
        }
      }
    }
  }

  /// Rasmni katta ko'rinishda ko'rsatish
  void _showImageDialog(PartModel part) {
    final imageFile = ImageService.getImageFile(part.imagePath);
    final hasImage = imageFile != null && imageFile.existsSync();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        part.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Image
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            imageFile!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 300,
                                height: 300,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Image not found', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      : Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image, size: 64, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No image', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                ),
              ),
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickAndUpdateImage(part);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Change'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    if (hasImage) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          if (part.imagePath != null) {
                            await ImageService.deleteImage(part.imagePath);
                            part.imagePath = null;
                            // FIX: Service endi bool qaytaradi
                            final success = await _partService.updatePart(part);
                            if (mounted) {
                              if (success) {
                                _showSnackBar('Image deleted', Colors.orange);
                              } else {
                                _showSnackBar('Failed to delete image. Please try again.', Colors.red);
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowStockParts = _getLowStockParts();
    final lowStockCount = lowStockParts.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Parts'),
            if (lowStockCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$lowStockCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search, Filter va Sort section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                SearchBarWidget(
                  controller: _searchController,
                  hintText: 'Search parts...',
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                // Low stock filter
                Row(
                  children: [
                    FilterChipWidget(
                      label: 'Low Stock',
                      selected: _showLowStockOnly,
                      onSelected: (selected) {
                        setState(() {
                          _showLowStockOnly = selected;
                        });
                      },
                      icon: Icons.warning,
                    ),
                  ],
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
                    SortOption.quantityAsc,
                    SortOption.quantityDesc,
                  ],
                ),
              ],
            ),
          ),

          // Kam qolgan qismlar section (agar bor bo'lsa)
          if (lowStockCount > 0 && !_showLowStockOnly)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Low Stock Alert',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showLowStockOnly = true;
                          });
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: lowStockParts.length > 5 ? 5 : lowStockParts.length,
                      itemBuilder: (context, index) {
                        final part = lowStockParts[index];
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  part.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${part.quantity} / ${part.minQuantity}',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Parts list
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _boxService.partsListenable,
              builder: (context, Box<PartModel> box, _) {
                final parts = _getFilteredParts();

                if (parts.isEmpty) {
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
                          icon: Icons.build,
                          title: box.isEmpty 
                              ? 'No parts yet' 
                              : 'No parts match your filters',
                          subtitle: box.isEmpty
                              ? 'Tap the + button to add a part'
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
                    padding: const EdgeInsets.all(12),
                    itemCount: parts.length,
                    itemBuilder: (context, index) {
                    final part = parts[index];
                    final isLowStock = part.quantity < part.minQuantity;
                    final statusColor = isLowStock ? Colors.red : Colors.green;
                    final imageFile = ImageService.getImageFile(part.imagePath);
                    final hasImage = imageFile != null && imageFile.existsSync();

                    return AnimatedListItem(
                      delay: index * 50,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: isLowStock ? Colors.red.shade50 : null,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _editPart(part),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Rasm - katta va chiroyli
                                GestureDetector(
                                  onTap: () => _showImageDialog(part),
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: statusColor.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: hasImage
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.file(
                                              imageFile!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return _buildImagePlaceholder(statusColor);
                                              },
                                            ),
                                          )
                                        : _buildImagePlaceholder(statusColor),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Ma'lumotlar
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        part.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isLowStock ? Colors.red.shade700 : null,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      // Quantity va Min Quantity ma'lumotlari
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          // Quantity badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isLowStock 
                                                  ? Colors.orange.shade50 
                                                  : Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isLowStock 
                                                    ? Colors.orange.shade300 
                                                    : Colors.blue.shade300,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.inventory_2,
                                                  size: 16,
                                                  color: isLowStock 
                                                      ? Colors.orange.shade700 
                                                      : Colors.blue.shade700,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${part.quantity}',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: isLowStock 
                                                        ? Colors.orange.shade900 
                                                        : Colors.blue.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Min Quantity badge (agar low stock bo'lsa)
                                          if (isLowStock)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.red.shade300,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.warning_amber_rounded,
                                                    size: 16,
                                                    color: Colors.red.shade700,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Min: ${part.minQuantity}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.red.shade900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              part.status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (isLowStock)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.warning,
                                                    size: 14,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Low Stock',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.red,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // 3-dots menu for actions
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editPart(part);
                                    } else if (value == 'delete') {
                                      _deletePart(part);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit, size: 20, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Text(AppLocalizations.of(context)?.translate('edit') ?? 'Edit'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete, size: 20, color: Colors.red),
                                          const SizedBox(width: 8),
                                          Text(AppLocalizations.of(context)?.translate('delete') ?? 'Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _nameController.clear();
          _quantityController.clear();
          _minQuantityController.clear();
          _selectedImage = null;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add New Part'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rasm picker
                    ImagePickerWidget(
                      currentImagePath: null,
                      onImagePicked: (imageFile) {
                        setState(() {
                          _selectedImage = imageFile;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Part Name',
                        border: OutlineInputBorder(),
                        hintText: 'Enter part name',
                        prefixIcon: Icon(Icons.label),
                      ),
                      autofocus: true,
                      onSubmitted: (_) => _addPart(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                        hintText: 'Enter quantity',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _addPart(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _minQuantityController,
                      decoration: const InputDecoration(
                        labelText: 'Min Quantity (Alert Threshold)',
                        border: OutlineInputBorder(),
                        hintText: 'Enter minimum quantity',
                        prefixIcon: Icon(Icons.warning),
                        helperText: 'Alert when quantity falls below this',
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _addPart(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _nameController.clear();
                    _quantityController.clear();
                    _minQuantityController.clear();
                    _selectedImage = null;
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _addPart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Part'),
      ),
    );
  }

  /// Rasm placeholder widget
  Widget _buildImagePlaceholder(Color statusColor) {
    return Container(
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 32,
            color: statusColor.withOpacity(0.6),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to add',
            style: TextStyle(
              fontSize: 10,
              color: statusColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
