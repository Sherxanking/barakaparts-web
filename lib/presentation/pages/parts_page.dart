/// Parts Page - Inventory parts management
/// 
/// WHY: Fixed syntax error (moved _buildImagePlaceholder inside class), added mounted checks, and improved error handling
/// Handles parts CRUD operations with real-time sync and proper error handling

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/part.dart';
import '../../domain/repositories/part_repository.dart';
import '../../core/di/service_locator.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../data/services/image_service.dart';
import '../../infrastructure/datasources/supabase_client.dart';
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
  // Repository
  final PartRepository _partRepository = ServiceLocator.instance.partRepository;

  // Data state
  List<Part> _parts = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Stream subscription
  StreamSubscription<Either<Failure, List<Part>>>? _partsStreamSubscription;

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
    _loadParts();
    _listenToParts();
  }

  /// Parts ni yuklash (Supabase dan)
  Future<void> _loadParts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _partRepository.getAllParts();

    result.fold(
          (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
        if (mounted) {
          _showSnackBar('Failed to load parts: ${failure.message}', Colors.red);
        }
      },
          (parts) {
        setState(() {
          _isLoading = false;
          _parts = parts;
        });
      },
    );
  }

  /// Real-time updates uchun stream listener
  /// WHY: Fixed stream error handling - properly catches errors and updates UI safely
  /// Ensures realtime updates are received and displayed immediately
  void _listenToParts() {
    debugPrint('🔔 Setting up realtime stream for parts...');
    
    // Cancel existing subscription if any
    _partsStreamSubscription?.cancel();
    
    _partsStreamSubscription = _partRepository.watchParts().listen(
      (result) {
        result.fold(
          (failure) {
            // Error bo'lsa, faqat log qilamiz va error state ni yangilaymiz
            debugPrint('❌ Stream error: ${failure.message}');
            if (mounted) {
              setState(() {
                _errorMessage = failure.message;
              });
            }
          },
          (parts) {
            // Ma'lumotlar yangilandi
            debugPrint('✅ Realtime update: ${parts.length} parts received');
            if (mounted) {
              setState(() {
                _parts = parts;
                _errorMessage = null; // Clear error on success
                _isLoading = false; // Ensure loading is false when data arrives
              });
            }
          },
        );
      },
      onError: (error) {
        debugPrint('❌ Stream subscription error: $error');
        if (mounted) {
          setState(() {
            _errorMessage = 'Stream error: $error';
          });
        }
      },
      cancelOnError: false, // Don't cancel on error, keep listening
      onDone: () {
        debugPrint('⚠️ Stream subscription closed');
      },
    );
    
    debugPrint('✅ Realtime stream subscription active');
  }

  @override
  void dispose() {
    // FIX: Listener ni olib tashlash dispose dan oldin
    _searchController.removeListener(_searchListener);
    _nameController.dispose();
    _quantityController.dispose();
    _minQuantityController.dispose();
    _searchController.dispose();
    _partsStreamSubscription?.cancel();
    super.dispose();
  }

  /// Kam qolgan qismlarni olish (minQuantity dan kam)
  List<Part> _getLowStockParts() {
    return _parts.where((part) => part.isLowStock).toList();
  }

  /// Filtrlangan va tartiblangan partlarni olish
  List<Part> _getFilteredParts() {
    List<Part> parts = _parts;

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      parts = parts.where((part) =>
          part.name.toLowerCase().contains(query)
      ).toList();
    }

    // Low stock filter
    if (_showLowStockOnly) {
      parts = parts.where((part) => part.isLowStock).toList();
    }

    // Sort
    if (_selectedSortOption != null) {
      switch (_selectedSortOption!) {
        case SortOption.nameAsc:
          parts.sort((a, b) => a.name.compareTo(b.name));
          break;
        case SortOption.nameDesc:
          parts.sort((a, b) => b.name.compareTo(a.name));
          break;
        case SortOption.quantityAsc:
          parts.sort((a, b) => a.quantity.compareTo(b.quantity));
          break;
        case SortOption.quantityDesc:
          parts.sort((a, b) => b.quantity.compareTo(a.quantity));
          break;
        default:
          break;
      }
    }

    return parts;
  }

  /// Yangi qism qo'shish
  /// WHY: Added comprehensive error handling, validation, and mounted checks to prevent crashes
  Future<void> _addPart() async {
    if (!mounted) return;
    
    try {
      // Validate input
      final nameRaw = _nameController.text.trim();
      if (nameRaw.isEmpty) {
        if (mounted) {
          _showSnackBar('Please enter a part name', Colors.red);
        }
        return;
      }
      
      // WHY: Auto-capitalize first letter of part name
      // Capitalize first letter, keep rest as-is (don't force lowercase)
      final name = nameRaw.isEmpty 
          ? nameRaw 
          : nameRaw[0].toUpperCase() + (nameRaw.length > 1 ? nameRaw.substring(1) : '');

      final quantityStr = _quantityController.text.trim();
      final quantity = int.tryParse(quantityStr);
      if (quantity == null || quantity < 0) {
        if (mounted) {
          _showSnackBar('Quantity must be a non-negative number', Colors.red);
        }
        return;
      }

      final minQuantityStr = _minQuantityController.text.trim();
      final minQuantity = int.tryParse(minQuantityStr) ?? 3;
      if (minQuantity < 0) {
        if (mounted) {
          _showSnackBar('Min quantity cannot be negative', Colors.red);
        }
        return;
      }

      final partId = const Uuid().v4();
      String? imagePath;

      // Rasmni saqlash (try/catch bilan)
      try {
        if (_selectedImage != null) {
          imagePath = await ImageService.saveImage(_selectedImage!, partId);
        }
      } catch (e) {
        debugPrint('⚠️ Image save error: $e');
        // Continue without image if save fails
      }

      // WHY: Set createdBy to current user ID for proper RLS policy compliance
      final currentUserId = AppSupabaseClient.instance.currentUserId;
      if (currentUserId == null) {
        if (mounted) {
          _showSnackBar('You must be logged in to create parts', Colors.red);
        }
        return;
      }

      final part = Part(
        id: partId,
        name: name,
        quantity: quantity,
        minQuantity: minQuantity,
        imagePath: imagePath,
        createdBy: currentUserId, // Set created_by for RLS policy
        createdAt: DateTime.now(),
      );

      debugPrint('📝 Creating part: $name (quantity: $quantity, created_by: $currentUserId)');
      final result = await _partRepository.createPart(part);

      if (!mounted) return;

      result.fold(
        (failure) {
          debugPrint('❌ Part creation failed: ${failure.message}');
          if (mounted) {
            _showSnackBar('Failed to add part: ${failure.message}', Colors.red);
          }
        },
        (createdPart) {
          if (mounted) {
            _nameController.clear();
            _quantityController.clear();
            _minQuantityController.clear();
            _selectedImage = null;
            _showSnackBar('Part added successfully', Colors.green);
            Navigator.pop(context);
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Create part error: $e');
      if (mounted) {
        _showSnackBar('Unexpected error: ${e.toString()}', Colors.red);
      }
    }
  }

  /// Qismni o'chirish
  Future<void> _deletePart(Part part) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
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
      // Rasmni o'chirish
      if (part.imagePath != null) {
        await ImageService.deleteImage(part.imagePath);
      }

      final result = await _partRepository.deletePart(part.id);

      result.fold(
            (failure) {
          if (mounted) {
            _showSnackBar(
                'Failed to delete part: ${failure.message}', Colors.red);
          }
        },
            (_) {
          if (mounted) {
            _showSnackBar('Part deleted', Colors.orange);
          }
        },
      );
    }
  }

  /// Qismni tahrirlash
  Future<void> _editPart(Part part) async {
    _nameController.text = part.name;
    _quantityController.text = part.quantity.toString();
    _minQuantityController.text = part.minQuantity.toString();
    _currentEditImagePath = part.imagePath;
    _selectedImage = null;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
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
                  if (_nameController.text
                      .trim()
                      .isEmpty) {
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
                    newImagePath =
                    await ImageService.saveImage(_selectedImage!, part.id);
                  } else
                  if (_currentEditImagePath == null && part.imagePath != null) {
                    // Rasm o'chirilgan bo'lsa
                    await ImageService.deleteImage(part.imagePath);
                    newImagePath = null;
                  }

                  final updatedPart = part.copyWith(
                    name: _nameController.text.trim(),
                    quantity: (int.tryParse(_quantityController.text) ??
                        part.quantity).clamp(0, double.infinity).toInt(),
                    minQuantity: (int.tryParse(_minQuantityController.text) ??
                        part.minQuantity).clamp(0, double.infinity).toInt(),
                    imagePath: newImagePath,
                    updatedAt: DateTime.now(),
                  );

                  final result = await _partRepository.updatePart(updatedPart);

                  result.fold(
                        (failure) {
                      if (mounted) {
                        _showSnackBar(
                            'Failed to update part: ${failure.message}',
                            Colors.red);
                      }
                    },
                        (updated) {
                      if (mounted) {
                        _nameController.clear();
                        _quantityController.clear();
                        _minQuantityController.clear();
                        _selectedImage = null;
                        _currentEditImagePath = null;
                        Navigator.pop(context);
                        _showSnackBar('Part updated', Colors.green);
                      }
                    },
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }


  /// Rasm tanlash va yangilash
  Future<void> _pickAndUpdateImage(Part part) async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(
                      Icons.camera_alt, size: 32, color: Colors.blue),
                  title: const Text(
                      'Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Take a new photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(
                      Icons.photo_library, size: 32, color: Colors.green),
                  title: const Text(
                      'Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
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
          final updatedPart = part.copyWith(
            imagePath: newImagePath,
            updatedAt: DateTime.now(),
          );

          final result = await _partRepository.updatePart(updatedPart);

          result.fold(
                (failure) {
              if (mounted) {
                _showSnackBar(
                    'Failed to update image: ${failure.message}', Colors.red);
              }
            },
                (updated) {
              if (mounted) {
                _showSnackBar('Image updated', Colors.green);
              }
            },
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error: ${e.toString()}', Colors.red);
        }
      }
    }
  }

  /// Rasmni katta ko'rinishda ko'rsatish
  void _showImageDialog(Part part) {
    final imageFile = ImageService.getImageFile(part.imagePath);
    final hasImage = imageFile != null && imageFile.existsSync();

    showDialog(
      context: context,
      builder: (context) =>
          Dialog(
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
                      color: Theme
                          .of(context)
                          .colorScheme
                          .primaryContainer,
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
                                  Icon(Icons.broken_image, size: 64,
                                      color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Image not found',
                                      style: TextStyle(color: Colors.grey)),
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
                            Text('No image', style: TextStyle(
                                color: Colors.grey)),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                        if (hasImage) ...[
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              if (part.imagePath != null) {
                                await ImageService.deleteImage(part.imagePath);
                                final updatedPart = part.copyWith(
                                  imagePath: null,
                                  updatedAt: DateTime.now(),
                                );

                                final result = await _partRepository.updatePart(
                                    updatedPart);

                                result.fold(
                                      (failure) {
                                    if (mounted) {
                                      _showSnackBar(
                                          'Failed to delete image: ${failure
                                              .message}', Colors.red);
                                    }
                                  },
                                      (updated) {
                                    if (mounted) {
                                      _showSnackBar(
                                          'Image deleted', Colors.orange);
                                    }
                                  },
                                );
                              }
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
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
              color: Theme
                  .of(context)
                  .colorScheme
                  .surface,
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
                      itemCount: lowStockParts.length > 5 ? 5 : lowStockParts
                          .length,
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $_errorMessage',
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadParts,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadParts,
              child: Builder(
                builder: (context) {
                  final parts = _getFilteredParts();

                  if (parts.isEmpty) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery
                            .of(context)
                            .size
                            .height * 0.6,
                        child: EmptyStateWidget(
                          icon: Icons.build,
                          title: _parts.isEmpty
                              ? 'No parts yet'
                              : 'No parts match your filters',
                          subtitle: _parts.isEmpty
                              ? 'Tap the + button to add a part'
                              : 'Try adjusting your search or filters',
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
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
                  );
                },
              ),
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
  /// WHY: Moved inside class to fix syntax error - method was incorrectly placed outside class
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
