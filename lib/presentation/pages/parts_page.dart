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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/part_model.dart';
import '../../data/services/hive_box_service.dart';
import '../../data/services/part_service.dart';
import '../../data/services/image_service.dart';
import '../../core/di/service_locator.dart';
import '../../domain/entities/part.dart' as domain;
import '../widgets/search_bar_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/filter_chip_widget.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/image_picker_widget.dart';
import '../../l10n/app_localizations.dart';
import '../../core/services/auth_state_service.dart';
import '../../core/extensions/status_localization_extension.dart';

class PartsPage extends StatefulWidget {
  const PartsPage({super.key});

  @override
  State<PartsPage> createState() => _PartsPageState();
}

class _PartsPageState extends State<PartsPage> {
  // Services
  final HiveBoxService _boxService = HiveBoxService();
  final PartService _partService = PartService();
  
  /// Check if current user can create parts
  bool get _canCreateParts {
    final user = AuthStateService().currentUser;
    return user != null && user.canCreateParts();
  }
  
  // Chrome uchun state
  List<PartModel> _webParts = [];
  bool _isLoadingWebParts = false;

  // FIX: Duplicate prevention - loading state
  bool _isCreatingPart = false;
  
  // FIX: Duplicate name validation
  String? _nameValidationError;

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
    
    // FIX: Real-time duplicate name validation
    _nameController.addListener(_validatePartName);
    
    // FIX: Chrome'da partslarni yuklash
    if (kIsWeb) {
      // PostFrameCallback orqali yuklash - UI render bo'lgandan keyin
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadWebParts();
        }
      });
    }
  }
  
  /// Validate part name for duplicates (case-insensitive, trimmed)
  void _validatePartName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameValidationError = null;
      });
      return;
    }
    
    // Check for duplicate in Hive
    final normalizedName = name.toLowerCase();
    final hasDuplicate = _partService.getAllParts().any((part) {
      return part.name.trim().toLowerCase() == normalizedName;
    });
    
    setState(() {
      _nameValidationError = hasDuplicate 
          ? 'A part with this name already exists'
          : null;
    });
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
    _quantityController.dispose();
    _minQuantityController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Hive box ochilganligini tekshirish
  bool _isPartsBoxOpen() {
    try {
      return Hive.isBoxOpen('partsBox');
    } catch (e) {
      return false;
    }
  }

  /// Part ID bo'yicha Hive box index topish
  /// FIX: Filtered list index emas, real Hive index qaytaradi
  int? _findHiveIndexById(String partId) {
    try {
      if (!_isPartsBoxOpen()) {
        return null;
      }
      final box = _boxService.partsBox;
      for (int i = 0; i < box.length; i++) {
        final part = box.getAt(i);
        if (part != null && part.id == partId) {
          return i;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Kam qolgan qismlarni olish (minQuantity dan kam)
  List<PartModel> _getLowStockParts() {
    try {
      return _partService.getAllParts().where((part) {
        return part.quantity < part.minQuantity;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Filtrlangan va tartiblangan partlarni olish
  /// FIX: Xavfsiz Hive kirish - xatolik bo'lsa bo'sh ro'yxat qaytarish
  /// FIX: Chrome'da box ochilganligini tekshirmasdan to'g'ridan-to'g'ri service'dan olish
  List<PartModel> _getFilteredParts() {
    try {
      // FIX: Chrome'da Hive box ochilmaydi - state'dan olish
      if (kIsWeb) {
        // Chrome'da state'dan olish
        List<PartModel> parts = List.from(_webParts);

        // Qidiruv
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          parts = parts.where((part) {
            return part.name.toLowerCase().contains(query);
          }).toList();
        }

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
      
      // Mobile/Desktop - box ochilganligini tekshirish
      if (!_isPartsBoxOpen()) {
        return [];
      }
      
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
    } catch (e) {
      return [];
    }
  }

  /// Yangi qism qo'shish
  /// FIX: Duplicate prevention - loading state bilan
  Future<void> _addPart() async {
    // FIX: Agar yaratish jarayoni davom etayotgan bo'lsa, qayta bosilishini oldini olish
    if (_isCreatingPart) {
      debugPrint('⚠️ Part creation already in progress, ignoring duplicate request');
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showSnackBar(AppLocalizations.of(context)?.translate('enterPartName') ?? 'Please enter a part name', Colors.red);
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 1;
    if (quantity < 0) {
      _showSnackBar(AppLocalizations.of(context)?.translate('quantityCannotBeNegative') ?? 'Quantity cannot be negative', Colors.red);
      return;
    }

    // FIX: Loading state'ni o'rnatish
    if (mounted) {
      setState(() {
        _isCreatingPart = true;
      });
    }

    try {
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
          _nameValidationError = null;
          Navigator.pop(context);
          // FIX: UI ni darhol yangilash
          setState(() {});
          _showSnackBar(AppLocalizations.of(context)?.translate('partAdded') ?? 'Part added successfully', Colors.green);
        } else {
          // Check if it's a duplicate name error
          final normalizedName = part.name.trim().toLowerCase();
          final hasDuplicate = _partService.getAllParts().any((p) {
            return p.name.trim().toLowerCase() == normalizedName;
          });
          
          if (hasDuplicate) {
            setState(() {
              _nameValidationError = AppLocalizations.of(context)?.translate('duplicatePartName') ?? 'A part with this name already exists';
            });
            // FIX: Dialog yopilgandan keyin xabar ko'rsatish
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showSnackBar(AppLocalizations.of(context)?.translate('duplicatePartName') ?? 'A part with this name already exists. Please use a different name.', Colors.red);
              }
            });
          } else {
            // FIX: Dialog yopilgandan keyin xabar ko'rsatish
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showSnackBar(AppLocalizations.of(context)?.translate('failedToAddPart') ?? 'Failed to add part. Please try again.', Colors.red);
              }
            });
          }
        }
      }
    } finally {
      // FIX: Loading state'ni tozalash
      if (mounted) {
        setState(() {
          _isCreatingPart = false;
        });
      }
    }
  }

  /// Qismni o'chirish
  Future<void> _deletePart(PartModel part) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.translate('deletePart') ?? 'Delete Part'),
        content: Text('${AppLocalizations.of(context)?.translate('deletePartConfirm') ?? 'Are you sure you want to delete'} ${part.name}?'),
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

    if (confirmed == true && mounted) {
      try {
        // FIX: Filtered list index emas, real Hive index ishlatish
        final hiveIndex = _findHiveIndexById(part.id);
        
        if (hiveIndex == null) {
          if (mounted) {
            _showSnackBar(AppLocalizations.of(context)?.translate('partNotFoundInStorage') ?? 'Part not found in storage', Colors.red);
          }
          return;
        }
        
        // Rasmni o'chirish
        if (part.imagePath != null) {
          try {
            await ImageService.deleteImage(part.imagePath);
          } catch (e) {
            // Rasm o'chirish xatosi e'tiborsiz qoldiriladi
          }
        }
        
        // FIX: Real Hive index ishlatish
        final success = await _partService.deletePart(hiveIndex);
        if (mounted) {
          if (success) {
            // FIX: UI ni darhol yangilash
            setState(() {});
            // FIX: Chrome'da partslarni qayta yuklash
            if (kIsWeb) {
              await _loadWebParts();
            }
            _showSnackBar(AppLocalizations.of(context)?.translate('partDeleted') ?? 'Part deleted', Colors.orange);
          } else {
            _showSnackBar(AppLocalizations.of(context)?.translate('failedToDeleteOrder') ?? 'Failed to delete part. Please try again.', Colors.red);
          }
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('${AppLocalizations.of(context)?.translate('errorDeletingPart') ?? 'Error deleting part'}: ${e.toString()}', Colors.red);
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
        title: Text(AppLocalizations.of(context)?.translate('editPart') ?? 'Edit Part'),
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
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.translate('partName') ?? 'Part Name',
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.translate('quantity') ?? 'Quantity',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _minQuantityController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.of(context)?.translate('minQuantity') ?? 'Min Quantity'} (${AppLocalizations.of(context)?.translate('alertThreshold') ?? 'Alert Threshold'})',
                  border: const OutlineInputBorder(),
                  helperText: AppLocalizations.of(context)?.translate('alertWhenQuantityFallsBelow') ?? 'Alert when quantity falls below this',
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
            child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_nameController.text.trim().isEmpty) {
                _showSnackBar(AppLocalizations.of(context)?.translate('enterPartName') ?? 'Please enter a part name', Colors.red);
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
                  // FIX: UI ni darhol yangilash
                  setState(() {});
                  // FIX: Chrome'da partslarni qayta yuklash
                  if (kIsWeb) {
                    await _loadWebParts();
                  }
                  _showSnackBar(AppLocalizations.of(context)?.translate('partUpdated') ?? 'Part updated', Colors.green);
                } else {
                  _showSnackBar(AppLocalizations.of(context)?.translate('failedToAddPart') ?? 'Failed to update part. Please try again.', Colors.red);
                }
              }
            },
            child: Text(AppLocalizations.of(context)?.translate('save') ?? 'Save'),
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
        title: Text(AppLocalizations.of(context)?.translate('selectImageSource') ?? 'Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.camera_alt, size: 32, color: Colors.blue),
              title: Text(AppLocalizations.of(context)?.translate('camera') ?? 'Camera', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(AppLocalizations.of(context)?.translate('takeNewPhoto') ?? 'Take a new photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.photo_library, size: 32, color: Colors.green),
              title: Text(AppLocalizations.of(context)?.translate('gallery') ?? 'Gallery', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(AppLocalizations.of(context)?.translate('chooseFromGallery') ?? 'Choose from gallery'),
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
              // FIX: UI ni darhol yangilash
              setState(() {});
              _showSnackBar(AppLocalizations.of(context)?.translate('imageUpdated') ?? 'Image updated', Colors.green);
            } else {
              _showSnackBar(AppLocalizations.of(context)?.translate('failedToUpdateImage') ?? 'Failed to update image. Please try again.', Colors.red);
            }
          }
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('${AppLocalizations.of(context)?.translate('error') ?? 'Error'}: ${e.toString()}', Colors.red);
        }
      }
    }
  }

  /// Rasmni katta ko'rinishda ko'rsatish
  void _showImageDialog(PartModel part) {
    // FIX: Supabase Storage URL yoki local file path
    final imagePath = part.imagePath;
    final isNetworkImage = imagePath != null && 
        (imagePath.startsWith('http://') || imagePath.startsWith('https://'));
    final imageFile = !isNetworkImage ? ImageService.getImageFile(imagePath) : null;
    final hasImage = isNetworkImage || (imageFile != null && imageFile.existsSync());

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
                          child: isNetworkImage
                              ? Image.network(
                                  imagePath!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 300,
                                      height: 300,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                          const SizedBox(height: 8),
                                          Text(AppLocalizations.of(context)?.translate('imageNotFound') ?? 'Image not found', style: const TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 300,
                                      height: 300,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Image.file(
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
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                          const SizedBox(height: 8),
                                          Text(AppLocalizations.of(context)?.translate('imageNotFound') ?? 'Image not found', style: const TextStyle(color: Colors.grey)),
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image, size: 64, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(AppLocalizations.of(context)?.translate('noImage') ?? 'No image', style: const TextStyle(color: Colors.grey)),
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
                      label: Text(AppLocalizations.of(context)?.translate('change') ?? 'Change'),
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
                                // FIX: UI ni darhol yangilash
                                setState(() {});
                                _showSnackBar(AppLocalizations.of(context)?.translate('imageDeleted') ?? 'Image deleted', Colors.orange);
                              } else {
                                _showSnackBar(AppLocalizations.of(context)?.translate('failedToDeleteImage') ?? 'Failed to delete image. Please try again.', Colors.red);
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.delete),
                        label: Text(AppLocalizations.of(context)?.translate('delete') ?? 'Delete'),
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
            Text(AppLocalizations.of(context)?.translate('parts') ?? 'Parts'),
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
                  hintText: AppLocalizations.of(context)?.translate('searchParts') ?? 'Search parts...',
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                // Low stock filter
                Row(
                  children: [
                    FilterChipWidget(
                      label: AppLocalizations.of(context)?.translate('lowStock') ?? 'Low Stock',
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
                        child: Text(AppLocalizations.of(context)?.translate('viewAll') ?? 'View All'),
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
            child: Builder(
              builder: (context) {
                // FIX: Chrome'da Hive ishlamaydi - fallback qo'shish
                // FIX: Faqat Chrome uchun fallback ishlatish, telefon uchun ValueListenableBuilder
                if (kIsWeb) {
                  // Chrome - to'g'ridan-to'g'ri state'dan olish
                  return _buildWebFallback();
                }
                
                // FIX: Telefon uchun Hive box ochilmagan bo'lsa, loading ko'rsatish
                if (!_isPartsBoxOpen()) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                // Mobile/Desktop - ValueListenableBuilder ishlatish
                return ValueListenableBuilder(
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
                    // FIX: Supabase Storage URL yoki local file path
                    final imagePath = part.imagePath;
                    final isNetworkImage = imagePath != null && 
                        (imagePath.startsWith('http://') || imagePath.startsWith('https://'));
                    final imageFile = !isNetworkImage ? ImageService.getImageFile(imagePath) : null;
                    final hasImage = isNetworkImage || (imageFile != null && imageFile.existsSync());

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
                                            child: isNetworkImage
                                                ? Image.network(
                                                    imagePath!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return _buildImagePlaceholder(statusColor);
                                                    },
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return Center(
                                                        child: CircularProgressIndicator(
                                                          value: loadingProgress.expectedTotalBytes != null
                                                              ? loadingProgress.cumulativeBytesLoaded /
                                                                  loadingProgress.expectedTotalBytes!
                                                              : null,
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : Image.file(
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
                                              part.status.localizedStatus(context),
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _canCreateParts
          ? FloatingActionButton.extended(
              onPressed: () {
          _nameController.clear();
          _quantityController.clear();
          _minQuantityController.clear();
          _selectedImage = null;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(AppLocalizations.of(context)?.translate('addPart') ?? 'Add New Part'),
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
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)?.translate('partName') ?? 'Part Name',
                        border: const OutlineInputBorder(),
                        hintText: AppLocalizations.of(context)?.translate('enterPartName') ?? 'Enter part name',
                        prefixIcon: const Icon(Icons.label),
                        errorText: _nameValidationError,
                        errorMaxLines: 2,
                      ),
                      autofocus: true,
                      onSubmitted: (_) {
                        if (_nameValidationError == null && !_isCreatingPart) {
                          _addPart();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)?.translate('quantity') ?? 'Quantity',
                        border: const OutlineInputBorder(),
                        hintText: AppLocalizations.of(context)?.translate('enterQuantity') ?? 'Enter quantity',
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _addPart(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _minQuantityController,
                      decoration: InputDecoration(
                        labelText: '${AppLocalizations.of(context)?.translate('minQuantity') ?? 'Min Quantity'} (${AppLocalizations.of(context)?.translate('alertThreshold') ?? 'Alert Threshold'})',
                        border: const OutlineInputBorder(),
                        hintText: AppLocalizations.of(context)?.translate('enterMinQuantity') ?? 'Enter minimum quantity',
                        prefixIcon: const Icon(Icons.warning),
                        helperText: AppLocalizations.of(context)?.translate('alertWhenQuantityFallsBelow') ?? 'Alert when quantity falls below this',
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
                    _nameValidationError = null;
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: (_isCreatingPart || _nameValidationError != null) ? null : _addPart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isCreatingPart
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(AppLocalizations.of(context)?.translate('add') ?? 'Add'),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)?.translate('addPart') ?? 'Add Part'),
      )
          : null, // Hide button if user can't create parts
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
            AppLocalizations.of(context)?.translate('tapToAdd') ?? 'Tap to add',
            style: TextStyle(
              fontSize: 10,
              color: statusColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// Chrome/Web uchun fallback widget
  /// FIX: Chrome'da Hive ishlamaydi - to'g'ridan-to'g'ri service'dan olish
  Widget _buildWebFallback() {
    // FIX: Chrome'da partslar yuklanayotgan bo'lsa, loading ko'rsatish
    if (kIsWeb && _isLoadingWebParts) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    // FIX: Agar partslar bo'sh bo'lsa va yuklanayotgan bo'lmasa, yuklashga harakat qilish
    if (kIsWeb && _webParts.isEmpty && !_isLoadingWebParts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadWebParts();
        }
      });
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final parts = _getFilteredParts();

    if (parts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          if (mounted) {
            // FIX: Chrome'da partslarni qayta yuklash
            if (kIsWeb) {
              await _loadWebParts();
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
              icon: Icons.build,
              title: 'No parts yet',
              subtitle: 'Tap the + button to add a part',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (mounted) {
          // FIX: Chrome'da partslarni qayta yuklash
          if (kIsWeb) {
            await _loadWebParts();
          }
          setState(() {});
        }
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: parts.length,
        itemBuilder: (context, index) {
          if (!mounted) {
            return const SizedBox.shrink();
          }
          
          try {
            final part = parts[index];
            final isLowStock = part.quantity < part.minQuantity;
            final statusColor = isLowStock ? Colors.red : Colors.green;
            // FIX: Supabase Storage URL yoki local file path
            final imagePath = part.imagePath;
            final isNetworkImage = imagePath != null && 
                (imagePath.startsWith('http://') || imagePath.startsWith('https://'));
            final imageFile = !isNetworkImage ? ImageService.getImageFile(imagePath) : null;
            final hasImage = isNetworkImage || (imageFile != null && imageFile.existsSync());

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
                        // Rasm
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
                                    child: isNetworkImage
                                        ? Image.network(
                                            imagePath!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return _buildImagePlaceholder(statusColor);
                                            },
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Center(
                                                child: CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded /
                                                          loadingProgress.expectedTotalBytes!
                                                      : null,
                                                ),
                                              );
                                            },
                                          )
                                        : Image.file(
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
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
                            ],
                          ),
                        ),
                        // Menu
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
          } catch (e) {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}
