/// Parts Page - Inventory parts management
/// 
/// WHY: Fixed part creation to include created_by field and improved error handling
/// Handles parts CRUD operations with real-time sync and proper error handling

import 'dart:async';
import 'dart:async';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/part.dart';
import '../../domain/repositories/part_repository.dart';
import '../../core/di/service_locator.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../data/services/image_service.dart';
import '../../data/services/excel_import_service.dart';
import '../../data/services/hive_box_service.dart';
import '../../infrastructure/datasources/supabase_client.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/sort_dropdown_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/filter_chip_widget.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/image_picker_widget.dart';
import '../../l10n/app_localizations.dart';
import '../../core/services/auth_state_service.dart';
import '../../core/services/error_handler_service.dart';
import 'part_history_page.dart';
import 'analytics_page.dart';

class PartsPage extends StatefulWidget {
  const PartsPage({super.key});

  @override
  State<PartsPage> createState() => _PartsPageState();
}

class _PartsPageState extends State<PartsPage> {
  // Repository
  final PartRepository _partRepository = ServiceLocator.instance.partRepository;
  final ExcelImportService _excelImportService = ExcelImportService();
  final HiveBoxService _boxService = HiveBoxService();

  // Data state (for initial load only)
  bool _isInitialLoading = true;
  bool _isImporting = false;
  
  // Stream will be used directly in StreamBuilder - no need for subscription

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _minQuantityController = TextEditingController();
  final TextEditingController _broughtByController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // State
  SortOption? _selectedSortOption;
  bool _showLowStockOnly = false;
  bool _showLowStockPanel = false;
  File? _selectedImage; // Tanlangan rasm (add/edit uchun)
  String? _currentEditImagePath; // Tahrirlash uchun hozirgi rasm yo'li

  // FIX: Listener funksiyasini saqlash - dispose da olib tashlash uchun
  late final VoidCallback _searchListener;
  Timer? _searchDebounceTimer; // Debounce timer

  @override
  void initState() {
    super.initState();
    _searchListener = () {
      // Debounce: 300ms kutish
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {});
        }
      });
    };
    _searchController.addListener(_searchListener);
    
    // Reduce initial loading time to prevent UI blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () { // Reduced from 2 seconds to 500ms
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
    _scrollController.dispose();
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_searchListener);
    _nameController.dispose();
    _quantityController.dispose();
    _minQuantityController.dispose();
    _broughtByController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Kam qolgan qismlarni olish (minQuantity dan kam)
  List<Part> _getLowStockParts(List<Part> parts) {
    return parts.where((part) => part.isLowStock).toList();
  }
  
  String _getStatusLabel(String status, AppLocalizations? l10n) {
    final normalized = status.toLowerCase();
    if (normalized == 'lowstock' || normalized == 'low_stock') {
      return l10n?.translate('statusLowStock') ?? 'Low stock';
    }
    if (normalized == 'available') {
      return l10n?.translate('statusAvailable') ?? 'Available';
    }
    return status.toUpperCase();
  }

  /// Filtrlangan va tartiblangan partlarni olish
  List<Part> _getFilteredParts(List<Part> parts) {

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
  /// WHY: Added comprehensive error handling and validation to prevent crashes
  Future<void> _addPart() async {
    try {
      // Permission check: only managers and boss can create parts
      final currentUser = AuthStateService().currentUser;
      if (currentUser == null || !currentUser.canCreateParts()) {
        _showSnackBar('Access denied: You cannot add parts', Colors.red);
        return;
      }

      // Validate input
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        _showSnackBar('Please enter a part name', Colors.red);
        return;
      }

      final quantityStr = _quantityController.text.trim();
      final quantity = int.tryParse(quantityStr);
      if (quantity == null || quantity < 0) {
        _showSnackBar('Quantity must be a non-negative number', Colors.red);
        return;
      }

      final minQuantityStr = _minQuantityController.text.trim();
      final minQuantity = int.tryParse(minQuantityStr) ?? 3;
      if (minQuantity < 0) {
        _showSnackBar('Min quantity cannot be negative', Colors.red);
        return;
      }

      final partId = const Uuid().v4();
      String? imagePath;
      final broughtBy = _broughtByController.text.trim().isEmpty 
          ? null 
          : _broughtByController.text.trim();

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
        _showSnackBar('You must be logged in to create parts', Colors.red);
        return;
      }

      final contactName = _contactNameController.text.trim().isEmpty 
          ? null 
          : _contactNameController.text.trim();
      final contactPhone = _contactPhoneController.text.trim().isEmpty 
          ? null 
          : _contactPhoneController.text.trim();

      final part = Part(
        id: partId,
        name: name,
        quantity: quantity,
        minQuantity: minQuantity,
        imagePath: imagePath,
        createdBy: currentUserId, // Set created_by for RLS policy
        broughtBy: broughtBy,
        contactName: contactName,
        contactPhone: contactPhone,
        createdAt: DateTime.now(),
      );

      debugPrint('📝 Creating part: $name (quantity: $quantity, created_by: $currentUserId)');
      final result = await _partRepository.createPart(part);

      result.fold(
        (failure) {
          if (mounted) {
            _showSnackBar('Failed to add part: ${ErrorHandlerService.instance.getErrorMessage(failure)}', Colors.red);
          }
        },
        (createdPart) {
          if (mounted) {
            _nameController.clear();
            _quantityController.clear();
            _minQuantityController.clear();
            _broughtByController.clear();
            _contactNameController.clear();
            _contactPhoneController.clear();
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
    final currentUser = AuthStateService().currentUser;
    if (currentUser == null || !currentUser.canDeleteParts()) {
      _showSnackBar('Access denied: You cannot delete parts', Colors.red);
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
            title: Text(l10n?.translate('deletePart') ?? 'Delete Part'),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            content: Text(
              '${l10n?.translate('deletePartConfirm') ?? 'Are you sure you want to delete this part?'}\n${part.name}',
            ),
            actions: [
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n?.translate('cancel') ?? 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n?.translate('delete') ?? 'Delete'),
              ),
            ],
          );
      },
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
    final currentUser = AuthStateService().currentUser;
    if (currentUser == null || !currentUser.canEditParts()) {
      _showSnackBar('Access denied: You cannot edit parts', Colors.red);
      return;
    }

    _nameController.text = part.name;
    _quantityController.text = part.quantity.toString();
    _minQuantityController.text = part.minQuantity.toString();
    _broughtByController.text = part.broughtBy ?? '';
    _contactNameController.text = part.contactName ?? '';
    _contactPhoneController.text = part.contactPhone ?? '';
    _currentEditImagePath = kIsWeb ? null : part.imagePath;
    _selectedImage = null;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
            title: Text(l10n?.translate('editPart') ?? 'Edit Part'),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n?.translate('partName') ?? 'Part Name',
                      border: const OutlineInputBorder(),
                      hintText: l10n?.translate('partNameHint') ?? 'Enter part name',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: l10n?.translate('quantity') ?? 'Quantity',
                      border: const OutlineInputBorder(),
                      helperText: l10n?.translate('quantityChangeHelper') ??
                          '⚠️ Miqdorni o\'zgartirish tasdiqlash talab qiladi',
                      helperMaxLines: 2,
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _minQuantityController,
                    decoration: InputDecoration(
                      labelText: l10n?.translate('minQuantityLabel') ?? 'Min Quantity',
                      border: const OutlineInputBorder(),
                      helperText: l10n?.translate('minQuantityHelper') ??
                          'Alert when quantity falls below this',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _broughtByController,
                    decoration: InputDecoration(
                      labelText: l10n?.translate('broughtByLabel') ?? 'Kim olib kelgan (Ixtiyoriy)',
                      border: const OutlineInputBorder(),
                      hintText: l10n?.translate('broughtByHint') ??
                          'Masalan: Ahmad, Boss, va hokazo',
                      helperText: l10n?.translate('broughtByHelper') ??
                          'Telefon bo‘lsa pastda Kontakt telefonni kiriting',
                      prefixIcon: const Icon(Icons.person_add),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _contactNameController,
                    decoration: InputDecoration(
                      labelText: l10n?.translate('contactNameLabel') ??
                          'Kontakt Ismi (Ixtiyoriy)',
                      border: const OutlineInputBorder(),
                      hintText: l10n?.translate('contactNameHint') ??
                          'Masalan: Ali, Supplier A',
                      prefixIcon: const Icon(Icons.contact_page),
                      helperText: l10n?.translate('contactNameHelper') ??
                          'Qismni olib keluvchi shaxs/kompaniya nomi',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contactPhoneController,
                    decoration: InputDecoration(
                      labelText: l10n?.translate('contactPhoneLabel') ??
                          'Kontakt Telefon (Ixtiyoriy)',
                      border: const OutlineInputBorder(),
                      hintText: l10n?.translate('contactPhoneHint') ??
                          'Masalan: +998901234567',
                      prefixIcon: const Icon(Icons.phone),
                      helperText: l10n?.translate('contactPhoneHelper') ??
                          'Qismni olib keluvchi shaxs/kompaniya telefon raqami',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            actions: [
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  _nameController.clear();
                  _quantityController.clear();
                  _minQuantityController.clear();
                  _selectedImage = null;
                  _currentEditImagePath = null;
                  Navigator.pop(context);
                },
                child: Text(l10n?.translate('cancel') ?? 'Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (_nameController.text
                      .trim()
                      .isEmpty) {
                    _showSnackBar(
                      l10n?.translate('partNameRequired') ?? 'Please enter a part name',
                      Colors.red,
                    );
                    return;
                  }

                  // Quantity o'zgarganda confirmation so'rash
                  final newQuantity = int.tryParse(_quantityController.text) ?? part.quantity;
                  final quantityChanged = newQuantity != part.quantity;
                  
                  if (quantityChanged) {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          l10n?.translate('quantityChangeTitle') ?? 'Miqdorni o\'zgartirish',
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n?.translate('oldQuantity') ?? 'Eski miqdor'}: ${part.quantity}',
                            ),
                            Text(
                              '${l10n?.translate('newQuantity') ?? 'Yangi miqdor'}: $newQuantity',
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n?.translate('quantityChangeWarning') ??
                                  'Miqdorni o\'zgartirish part hisobini o\'zgartirishi mumkin. '
                                  'Davom etasizmi?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(l10n?.translate('cancel') ?? 'Bekor qilish'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: Text(l10n?.translate('confirm') ?? 'Tasdiqlash'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true) {
                      return; // User cancelled
                    }
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
                    quantity: newQuantity.clamp(0, double.infinity).toInt(),
                    minQuantity: (int.tryParse(_minQuantityController.text) ??
                        part.minQuantity).clamp(0, double.infinity).toInt(),
                    imagePath: newImagePath,
                    broughtBy: _broughtByController.text.trim().isEmpty
                        ? null
                        : _broughtByController.text.trim(),
                    contactName: _contactNameController.text.trim().isEmpty
                        ? null
                        : _contactNameController.text.trim(),
                    contactPhone: _contactPhoneController.text.trim().isEmpty
                        ? null
                        : _contactPhoneController.text.trim(),
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
                        _broughtByController.clear();
                        _contactNameController.clear();
                        _contactPhoneController.clear();
                        _selectedImage = null;
                        _currentEditImagePath = null;
                        Navigator.pop(context);
                        _showSnackBar('Part updated', Colors.green);
                      }
                    },
                  );
                },
                child: Text(l10n?.translate('save') ?? 'Save'),
              ),
            ],
          );
      },
    );
  }

  /// Qismni berib yuborish yoki brak qilish (hisobdan chiqarish)
  Future<void> _showPartOutflowDialog(Part part) async {
    final currentUser = AuthStateService().currentUser;
    if (currentUser == null || !currentUser.canEditParts()) {
      _showSnackBar('Access denied: You cannot adjust parts', Colors.red);
      return;
    }

    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    String actionType = 'issue';

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.translate('partOutflow') ?? 'Part chiqarish'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: actionType,
              decoration: InputDecoration(
                labelText: l10n?.translate('reason') ?? 'Sabab',
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'issue',
                  child: Text(l10n?.translate('issued') ?? 'Berib yuborildi'),
                ),
                DropdownMenuItem(
                  value: 'scrap',
                  child: Text(l10n?.translate('scrap') ?? 'Brak / Yaroqsiz'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  actionType = value;
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n?.translate('quantity') ?? 'Miqdor',
                border: const OutlineInputBorder(),
                helperText:
                    '${l10n?.translate('inStock') ?? 'Omborda'}: ${part.quantity}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: l10n?.translate('noteOptional') ?? 'Izoh (ixtiyoriy)',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.translate('cancel') ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.translate('save') ?? 'Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final qty = int.tryParse(qtyController.text.trim());
    if (qty == null || qty <= 0) {
      _showSnackBar('Miqdor noto\'g\'ri', Colors.red);
      return;
    }
    if (qty > part.quantity) {
      _showSnackBar('Miqdor ombordagidan ko\'p', Colors.red);
      return;
    }

    final newQuantity = part.quantity - qty;
    final reasonLabel = actionType == 'scrap' ? 'Brak' : 'Berib yuborildi';
    final extraNote = noteController.text.trim();
    final historyNotes = extraNote.isEmpty
        ? '$reasonLabel: -$qty'
        : '$reasonLabel: -$qty. $extraNote';

    final updatedPart = part.copyWith(
      quantity: newQuantity,
      updatedAt: DateTime.now(),
    );

    final result = await _partRepository.updatePart(
      updatedPart,
      // Use existing action type to avoid backend constraints; notes carry reason.
      historyAction: 'update',
      historyNotes: historyNotes,
    );

    result.fold(
      (failure) {
        if (mounted) {
          _showSnackBar('Failed: ${failure.message}', Colors.red);
        }
      },
      (_) {
        if (mounted) {
          _showSnackBar('Hisobdan chiqarildi', Colors.orange);
        }
      },
    );
  }

  /// Kontaktga telefon qilish
  Future<void> _callContact(String phoneNumber) async {
    try {
      // Telefon raqamini tozalash (bo'sh joylarni olib tashlash)
      final cleanPhone = phoneNumber.replaceAll(' ', '').replaceAll('-', '');
      final uri = Uri.parse('tel:$cleanPhone');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          _showSnackBar('Telefon qilish imkoni yo\'q: $phoneNumber', Colors.orange);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error calling contact: $e');
      if (mounted) {
        _showSnackBar('Telefon qilishda xatolik: $e', Colors.red);
      }
    }
  }

  /// Batch Add Parts Dialog - Professional yechim
  /// WHY: Bir nechta part'larni bir vaqtda qo'shish (kirim)
  Future<void> _showBatchAddDialog() async {
    final l10n = AppLocalizations.of(context);
    final currentUser = AuthStateService().currentUser;
    if (currentUser == null || !currentUser.canCreateParts()) {
      _showSnackBar('Access denied: You cannot add parts', Colors.red);
      return;
    }

    // Mavjud part'larni olish
    final allPartsResult = await _partRepository.getAllParts();
    
    // Tanlangan part'lar va ularning miqdorlari
    final Map<String, int> selectedParts = {};
    final Map<String, TextEditingController> quantityControllers = {};
    final TextEditingController noteController = TextEditingController();
    String searchQuery = '';
    
    allPartsResult.fold(
      (failure) {
        _showSnackBar('Xatolik: ${ErrorHandlerService.instance.getErrorMessage(failure)}', Colors.red);
        return;
      },
      (parts) {
        // Barcha part'lar uchun controller yaratish
        for (var part in parts) {
          quantityControllers[part.id] = TextEditingController();
        }
      },
    );
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return allPartsResult.fold(
          (failure) => AlertDialog(
            title: Text(l10n?.translate('batchAddParts') ?? 'Batch Add Parts'),
            content: Text(
              '${l10n?.translate('error') ?? 'Error'}: ${failure.message}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n?.translate('ok') ?? 'OK'),
              ),
            ],
          ),
          (parts) {
            // Filter parts by search query
            final filteredParts = searchQuery.isEmpty
                ? parts
                : parts.where((part) =>
                    part.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
            
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.add_shopping_cart, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(l10n?.translate('stockInTitle') ?? 'Kirim Qilish'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Text(
                          l10n?.translate('selectPartsAndQuantity') ?? 'Select parts and enter quantity',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                    const SizedBox(height: 16),
                    // Search bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: l10n?.translate('searchParts') ?? 'Search parts...',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Parts list
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height *
                            (MediaQuery.of(context).viewInsets.bottom > 0 ? 0.22 : 0.35),
                      ),
                      child: filteredParts.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  l10n?.translate('noPartsMatch') ?? 'No parts match your filters',
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filteredParts.length,
                              itemBuilder: (context, index) {
                                final part = filteredParts[index];
                                final controller = quantityControllers[part.id]!;
                                final isSelected = selectedParts.containsKey(part.id);
                                
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: isSelected ? Colors.green.shade50 : null,
                                  child: ListTile(
                                    title: Text(part.name),
                                    subtitle: Text('${l10n?.translate('quantity') ?? 'Quantity'}: ${part.quantity}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Checkbox
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (value) {
                                            setDialogState(() {
                                              if (value == true) {
                                                selectedParts[part.id] = 1;
                                                controller.text = '1';
                                              } else {
                                                selectedParts.remove(part.id);
                                                controller.text = '';
                                              }
                                            });
                                          },
                                        ),
                                        // Quantity input
                                        if (isSelected)
                                          SizedBox(
                                            width: 80,
                                            child: TextField(
                                              controller: controller,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                hintText: l10n?.translate('quantity') ?? 'Quantity',
                                                isDense: true,
                                                border: const OutlineInputBorder(),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              ),
                                              onChanged: (value) {
                                                if (value.trim().isEmpty) {
                                                  // Allow editing without unselecting the part
                                                  return;
                                                }
                                                final qty = int.tryParse(value) ?? 0;
                                                setDialogState(() {
                                                  if (qty > 0) {
                                                    selectedParts[part.id] = qty;
                                                  } else {
                                                    // Keep previous value to avoid accidental uncheck
                                                    final prevQty = selectedParts[part.id] ?? 1;
                                                    controller.text = prevQty.toString();
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (selectedParts.isNotEmpty) ...[
                      const Divider(),
                      Text(
                        'Tanlangan: ${selectedParts.length} ta qism',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: l10n?.translate('noteOptional') ?? 'Izoh (ixtiyoriy)',
                          hintText: l10n?.translate('noteHint') ??
                              'Masalan: kim olib keldi, qayerdan keldi',
                          prefixIcon: const Icon(Icons.note_alt),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(l10n?.translate('cancel') ?? 'Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: selectedParts.isEmpty
                      ? null
                      : () async {
                          // Batch add parts
                          await _batchAddParts(
                            selectedParts,
                            note: noteController.text.trim(),
                          );
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                  icon: const Icon(Icons.add),
                  label: Text('${l10n?.translate('add') ?? 'Add'} (${selectedParts.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
            },
          );
        },
      ),
    );
    for (var controller in quantityControllers.values) {
      controller.dispose();
    }
    noteController.dispose();
  }
  
  /// Batch add parts - bir nechta part'larni bir vaqtda qo'shish
  Future<void> _batchAddParts(
    Map<String, int> partsToAdd, {
    String? note,
  }) async {
    if (partsToAdd.isEmpty) return;
    
    // Loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      int successCount = 0;
      int failCount = 0;
      
      final l10n = AppLocalizations.of(context);
      final trimmedNote = (note ?? '').trim();
      // Har bir part uchun quantity ni oshirish
      for (var entry in partsToAdd.entries) {
        final partId = entry.key;
        final quantityToAdd = entry.value;
        
        if (quantityToAdd <= 0) continue;
        
        // Part ni olish
        final partResult = await _partRepository.getPartById(partId);
        await partResult.fold(
          (failure) async {
            failCount++;
            debugPrint('❌ Failed to get part $partId: ${failure.message}');
          },
          (part) async {
            if (part != null) {
              // Quantity ni oshirish
              final updatedPart = part.copyWith(
                quantity: part.quantity + quantityToAdd,
                updatedAt: DateTime.now(),
              );
              
              final updateResult = await _partRepository.updatePart(
                updatedPart,
                historyAction: 'add',
                historyNotes: trimmedNote.isEmpty
                    ? null
                    : '${l10n?.translate('stockInNote') ?? 'Kirim izohi'}: $trimmedNote (+$quantityToAdd)',
              );
              await updateResult.fold(
                (failure) async {
                  failCount++;
                  debugPrint('❌ Failed to update part ${part.name}: ${failure.message}');
                },
                (_) async {
                  successCount++;
                  debugPrint('✅ Added $quantityToAdd to ${part.name}');
                },
              );
            } else {
              failCount++;
            }
          },
        );
      }
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (successCount > 0) {
          _showSnackBar(
            '$successCount ta qism muvaffaqiyatli qo\'shildi${failCount > 0 ? ", $failCount ta xatolik" : ""}',
            failCount > 0 ? Colors.orange : Colors.green,
          );
        } else {
          _showSnackBar('Hech qanday qism qo\'shilmadi', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showSnackBar('Xatolik: $e', Colors.red);
      }
    }
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
    final hasNetworkImage = (part.imagePath ?? '').startsWith('http');
    final imageFile = hasNetworkImage || kIsWeb
        ? null
        : ImageService.getImageFile(part.imagePath);
    final hasImage = hasNetworkImage || (imageFile != null && imageFile.existsSync());

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
                              borderRadius: BorderRadius.circular(8),
                              child: hasNetworkImage
                                  ? Image.network(
                                      part.imagePath!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildImagePlaceholder(Colors.grey); // Use grey as default
                                      },
                                    )
                                  : Image.file(
                                      imageFile!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildImagePlaceholder(Colors.grey); // Use grey as default
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

  /// Import parts from Excel file
  Future<void> _importFromExcel() async {
    setState(() {
      _isImporting = true;
    });

    try {
      // 1. Pick Excel file
      final fileResult = await _excelImportService.pickExcelFile();
      
      if (!mounted) return;

      fileResult.fold(
        (failure) {
          setState(() {
            _isImporting = false;
          });
          _showSnackBar('Failed to pick file: ${ErrorHandlerService.instance.getErrorMessage(failure)}', Colors.red);
        },
        (file) async {
          if (file == null) {
            // User cancelled
            setState(() {
              _isImporting = false;
            });
            return;
          }

          // 2. Parse Excel file
          final parseResult = await _excelImportService.parsePartsFromExcel(file);
          
          if (!mounted) return;

          parseResult.fold(
            (failure) {
              setState(() {
                _isImporting = false;
              });
              _showSnackBar('Failed to parse Excel: ${ErrorHandlerService.instance.getErrorMessage(failure)}', Colors.red);
            },
            (parts) async {
              if (parts.isEmpty) {
                setState(() {
                  _isImporting = false;
                });
                _showSnackBar('No parts found in Excel file', Colors.orange);
                return;
              }

              final l10n = AppLocalizations.of(context);
              // 3. Show confirmation dialog
              final shouldImport = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n?.translate('importPartsTitle') ?? 'Import Parts'),
                  content: Text(
                    '${l10n?.translate('importPartsFound') ?? 'Found parts in Excel file'}: ${parts.length}\n\n'
                    '${l10n?.translate('importPartsConfirm') ?? 'Do you want to import them?'}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n?.translate('cancel') ?? 'Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n?.translate('import') ?? 'Import'),
                    ),
                  ],
                ),
              );

              if (shouldImport != true || !mounted) {
                setState(() {
                  _isImporting = false;
                });
                return;
              }

              // 4. Import parts one by one
              int successCount = 0;
              int failCount = 0;

              for (final part in parts) {
                // Ensure each imported part has a valid UUID for DB insert
                final newPart = part.copyWith(
                  id: const Uuid().v4(),
                  createdAt: DateTime.now(),
                );
                final result = await _partRepository.createPart(newPart);
                result.fold(
                  (failure) {
                    failCount++;
                    debugPrint('❌ Failed to import ${part.name}: ${failure.message}');
                  },
                  (created) {
                    successCount++;
                    debugPrint('✅ Imported: ${created.name}');
                  },
                );
              }

              if (!mounted) return;

              setState(() {
                _isImporting = false;
              });

              // 5. Show result
              _showSnackBar(
                'Imported: $successCount, Failed: $failCount',
                failCount == 0 ? Colors.green : Colors.orange,
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
      });
      _showSnackBar('Import error: ${e.toString()}', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Either<Failure, List<Part>>>(
      stream: _partRepository.watchParts(),
      builder: (context, snapshot) {
        // Handle loading state
        if (_isInitialLoading && !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Parts'), elevation: 0),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        
        // Handle error state
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Parts'), elevation: 0),
            body: ErrorDisplayWidget(
              error: snapshot.error,
              onRetry: () => setState(() => _isInitialLoading = true),
            ),
          );
        }
        
        // Handle data
        final parts = snapshot.data?.fold(
          (failure) {
            // Show user-friendly error message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final message = ErrorHandlerService.instance.getErrorMessage(failure);
                ErrorHandlerService.instance.showErrorSnackBar(context, message);
              }
            });
            return <Part>[];
          },
          (parts) => parts,
        ) ?? <Part>[];
        
        final l10n = AppLocalizations.of(context);
        final lowStockParts = _getLowStockParts(parts);
        // Use live parts list to match filtered view
        final lowStockCount = lowStockParts.length;
        final filteredParts = _getFilteredParts(parts);
        final showFilterBanner = _showLowStockOnly || _searchController.text.isNotEmpty;
        final totalParts = parts.length;
        final filteredCount = filteredParts.length;
        final totalQuantity = parts.fold<int>(0, (sum, part) => sum + part.quantity);
        final filteredQuantity = filteredParts.fold<int>(0, (sum, part) => sum + part.quantity);
        // Header height no longer fixed; using normal sliver content to avoid clipping.
        
        final currentUser = AuthStateService().currentUser;
        final canCreateParts = currentUser?.canCreateParts() ?? false;
        final canEditParts = currentUser?.canEditParts() ?? false;
        final canDeleteParts = currentUser?.canDeleteParts() ?? false;
        final canSeeAnalytics = currentUser?.canSeeAllLogs() ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Text(l10n?.translate('parts') ?? 'Parts'),
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
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: l10n?.translate('scrollToTop') ?? 'Scroll to top',
                onPressed: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
              PopupMenuButton<SortOption>(
                icon: const Icon(Icons.sort),
                tooltip: l10n?.translate('sort') ?? 'Sort',
                initialValue: _selectedSortOption,
                onSelected: (option) {
                  setState(() {
                    _selectedSortOption = option;
                  });
                },
                itemBuilder: (context) => const [
                  SortOption.nameAsc,
                  SortOption.nameDesc,
                  SortOption.quantityAsc,
                  SortOption.quantityDesc,
                ].map((option) {
                  return PopupMenuItem(
                    value: option,
                    child: Text(option.getLabel(context)),
                  );
                }).toList(),
              ),
              if (canSeeAnalytics)
                IconButton(
                  icon: const Icon(Icons.analytics),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AnalyticsPage()),
                    );
                  },
                  tooltip: 'Analytics',
                ),
              // Low Stock Filter Toggle (har doim ko'rsatiladi)
              IconButton(
                icon: Icon(
                  _showLowStockOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: _showLowStockOnly ? Colors.red : (lowStockCount > 0 ? Colors.orange : Colors.grey),
                ),
                onPressed: () {
                  setState(() {
                    _showLowStockOnly = !_showLowStockOnly;
                  });
                },
                tooltip: _showLowStockOnly 
                    ? (l10n?.translate('all') ?? 'All')
                    : (lowStockCount > 0
                        ? '${l10n?.translate('lowStock') ?? 'Low Stock'} ($lowStockCount)'
                        : (l10n?.translate('lowStockFilter') ?? 'Low Stock filter')),
              ),
              // Excel Import button (only for managers and boss)
              if (canCreateParts)
                IconButton(
                  icon: _isImporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  tooltip: l10n?.translate('importFromExcel') ?? 'Import from Excel',
                  onPressed: _isImporting ? null : _importFromExcel,
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() => _isInitialLoading = true);
              await Future.delayed(const Duration(milliseconds: 500));
              setState(() => _isInitialLoading = false);
            },
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              interactive: true,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Theme.of(context).colorScheme.surface,
                            child: SearchBarWidget(
                              controller: _searchController,
                              hintText: l10n?.translate('searchParts') ?? 'Search parts...',
                              onChanged: (_) => setState(() {}),
                              onClear: () => setState(() {}),
                            ),
                          ),
                          if (showFilterBanner) ...[
                            const SizedBox(height: 8),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.filter_alt, size: 16, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n?.translate('filterEnabled') ?? 'Filter enabled',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _showLowStockOnly = false;
                                      });
                                    },
                                    child: Text(l10n?.translate('clear') ?? 'Clear'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Qismlar statistikasi
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  size: 20,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 0),
                                      Row(
                                        children: [
                                          Text(
                                            '${l10n?.translate('totalQuantity') ?? 'Total quantity'}: ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '$totalQuantity',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade900,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (filteredQuantity != totalQuantity) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '($filteredQuantity ${l10n?.translate('showing') ?? 'shown'})',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blue.shade600,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    // Low Stock chip (minimal signal)
                    if (lowStockCount > 0 && !_showLowStockOnly)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  setState(() {
                                    _showLowStockOnly = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.red.shade200, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning, color: Colors.red.shade700, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${l10n?.translate('lowStockShort') ?? 'Low stock'}: $lowStockCount',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(Icons.chevron_right, color: Colors.red.shade700, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showLowStockOnly = true;
                                  });
                                },
                                child: Text(l10n?.translate('viewAll') ?? 'View All'),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (filteredParts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: EmptyStateWidget(
                            icon: Icons.build,
                            title: parts.isEmpty
                                ? (l10n?.translate('noParts') ?? 'No parts yet')
                                : (l10n?.translate('noPartsMatch') ?? 'No parts match your filters'),
                            subtitle: parts.isEmpty
                                ? (l10n?.translate('addFirstPart') ?? 'Tap the + button to add a part')
                                : (l10n?.translate('tryAdjustingFilters') ?? 'Try adjusting your search or filters'),
                          ),
                        ),
                      ),

                    if (filteredParts.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n?.translate('partsList') ?? 'Parts List',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.shade200, width: 1),
                                ),
                                child: Text(
                                  '${l10n?.translate('totalParts') ?? 'Total parts'}: $totalParts',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (filteredParts.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final part = filteredParts[index];
                              final isLowStock = part.quantity < part.minQuantity;
                              final statusColor = isLowStock ? Colors.red : Colors.green;
                              final hasNetworkImage = (part.imagePath ?? '').startsWith('http');
                              final imageFile = hasNetworkImage || kIsWeb
                                  ? null
                                  : ImageService.getImageFile(part.imagePath);
                              final hasImage = hasNetworkImage || (imageFile != null && imageFile.existsSync());
                              final animationDelay = kIsWeb ? 0 : (index * 50).clamp(0, 300);

                              return AnimatedListItem(
                                delay: animationDelay,
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  color: isLowStock ? Colors.red.shade50 : null,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: canEditParts ? () => _editPart(part) : null,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Rasm - ixcham
                                          GestureDetector(
                                            onTap: () => _showImageDialog(part),
                                            child: Container(
                                              width: 76,
                                              height: 76,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: statusColor.withOpacity(0.3),
                                                  width: 1.5,
                                                ),
                                              ),
                                            child: hasImage
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: hasNetworkImage
                                                        ? Image.network(
                                                            part.imagePath!,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return _buildImagePlaceholder(statusColor);
                                                            },
                                                            loadingBuilder: (context, child, loadingProgress) {
                                                              if (loadingProgress == null) return child;
                                                              return Container(
                                                                decoration: BoxDecoration(
                                                                  color: statusColor.withOpacity(0.1),
                                                                  borderRadius: BorderRadius.circular(10),
                                                                ),
                                                                child: const Center(
                                                                  child: SizedBox(
                                                                    width: 24,
                                                                    height: 24,
                                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                                  ),
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
                                          const SizedBox(width: 12),
                                          // Ma'lumotlar
                                          Expanded(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  part.name,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: isLowStock ? Colors.red.shade700 : null,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                // Qoldi va Min (bitta qatorda)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.inventory_2,
                                                      size: 14,
                                                      color: isLowStock
                                                          ? Colors.orange.shade700
                                                          : Colors.blue.shade700,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${l10n?.translate('stockLabel') ?? 'Stock'} '
                                                      '${part.quantity} · '
                                                      '${l10n?.translate('minLabel') ?? 'Min'} '
                                                      '${part.minQuantity}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: isLowStock
                                                            ? Colors.red.shade700
                                                            : Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
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
                                                        _getStatusLabel(part.status, l10n),
                                                        style: TextStyle(
                                                          fontSize: 10,
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
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons.warning,
                                                              size: 12,
                                                              color: Colors.red,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              l10n?.translate('lowStock') ?? 'Low Stock',
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                color: Colors.red,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    if (part.broughtBy != null && part.broughtBy!.isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.purple.withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons.person,
                                                              size: 12,
                                                              color: Colors.purple,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              '${part.broughtBy}',
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                color: Colors.purple,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    // Contact Name
                                                    if (part.contactName != null && part.contactName!.isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.blue.withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons.contact_page,
                                                              size: 12,
                                                              color: Colors.blue,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              part.contactName!,
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                color: Colors.blue,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    // Contact Phone (clickable)
                                                    if (part.contactPhone != null && part.contactPhone!.isNotEmpty)
                                                      InkWell(
                                                        onTap: () => _callContact(part.contactPhone!),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.green.withOpacity(0.2),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(
                                                              color: Colors.green.withOpacity(0.5),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              const Icon(
                                                                Icons.phone,
                                                                size: 12,
                                                                color: Colors.green,
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                part.contactPhone!,
                                                                style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors.green,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
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
                                              if (value == 'history') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => PartHistoryPage(
                                                      partId: part.id,
                                                      partName: part.name,
                                                    ),
                                                  ),
                                                );
                                      } else if (value == 'outflow') {
                                        _showPartOutflowDialog(part);
                                              } else if (value == 'edit') {
                                                _editPart(part);
                                              } else if (value == 'delete') {
                                                _deletePart(part);
                                              }
                                            },
                                            itemBuilder: (context) {
                                              final items = <PopupMenuEntry<String>>[
                                                PopupMenuItem(
                                                  value: 'history',
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.history, size: 20, color: Colors.purple),
                                                      const SizedBox(width: 8),
                                                      const Text('History'),
                                                    ],
                                                  ),
                                                ),
                                              ];

                                              if (canEditParts) {
                                                items.add(
                                                  PopupMenuItem(
                                                    value: 'outflow',
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.remove_circle_outline, size: 20, color: Colors.orange),
                                                        const SizedBox(width: 8),
                                                        const Text('Issue / Scrap'),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                                items.add(
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
                                                );
                                              }

                                              if (canDeleteParts) {
                                                items.add(
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
                                                );
                                              }

                                              return items;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: filteredParts.length,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          floatingActionButton: canCreateParts
              ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: Text(l10n?.translate('addSinglePart') ?? 'Add Single Part'),
                        onTap: () {
                          Navigator.pop(context);
                          _nameController.clear();
                          _quantityController.clear();
                          _minQuantityController.clear();
                          _broughtByController.clear();
                          _contactNameController.clear();
                          _contactPhoneController.clear();
                          _selectedImage = null;
                          showDialog(
                            context: context,
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Text(l10n?.translate('addPart') ?? 'Add New Part'),
                              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                    const SizedBox(height: 20),
                                    TextField(
                                      controller: _nameController,
                                      decoration: InputDecoration(
                                        labelText: l10n?.translate('partName') ?? 'Part Name',
                                        border: const OutlineInputBorder(),
                                        hintText: l10n?.translate('partNameHint') ??
                                            'Enter part name',
                                        prefixIcon: const Icon(Icons.label),
                                      ),
                                      autofocus: true,
                                      onSubmitted: (_) => _addPart(),
                                    ),
                                    const SizedBox(height: 20),
                                    TextField(
                                      controller: _quantityController,
                                      decoration: InputDecoration(
                                        labelText: l10n?.translate('quantity') ?? 'Quantity',
                                        border: const OutlineInputBorder(),
                                        hintText: l10n?.translate('quantityHint') ??
                                            'Enter quantity',
                                        prefixIcon: const Icon(Icons.numbers),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onSubmitted: (_) => _addPart(),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _minQuantityController,
                                      decoration: InputDecoration(
                                        labelText: l10n?.translate('minQuantityLabel') ??
                                            'Min Quantity',
                                        border: const OutlineInputBorder(),
                                        hintText: l10n?.translate('minQuantityHint') ??
                                            'Enter minimum quantity',
                                        prefixIcon: const Icon(Icons.warning),
                                        helperText: l10n?.translate('minQuantityHelper') ??
                                            'Alert when quantity falls below this',
                                      ),
                                      keyboardType: TextInputType.number,
                                      onSubmitted: (_) => _addPart(),
                                    ),
                                    TextField(
                                      controller: _contactNameController,
                                      decoration: InputDecoration(
                                        labelText: l10n?.translate('contactNameLabel') ??
                                            'Kontakt Ismi (Ixtiyoriy)',
                                        border: const OutlineInputBorder(),
                                        hintText: l10n?.translate('contactNameHint') ??
                                            'Masalan: Ali, Supplier A',
                                        prefixIcon: const Icon(Icons.contact_page),
                                        helperText: l10n?.translate('contactNameHelper') ??
                                            'Qismni olib keluvchi shaxs/kompaniya nomi',
                                      ),
                                      textCapitalization: TextCapitalization.words,
                                      onSubmitted: (_) => _addPart(),
                                    ),
                                    const SizedBox(height: 20),
                                    TextField(
                                      controller: _contactPhoneController,
                                      decoration: InputDecoration(
                                        labelText: l10n?.translate('contactPhoneLabel') ??
                                            'Kontakt Telefon (Ixtiyoriy)',
                                        border: const OutlineInputBorder(),
                                        hintText: l10n?.translate('contactPhoneHint') ??
                                            'Masalan: +998901234567',
                                        prefixIcon: const Icon(Icons.phone),
                                        helperText: l10n?.translate('contactPhoneHelper') ??
                                            'Qismni olib keluvchi shaxs/kompaniya telefon raqami',
                                      ),
                                      keyboardType: TextInputType.phone,
                                      onSubmitted: (_) => _addPart(),
                                    ),
                                    const SizedBox(height: 20),
                                    TextField(
                                      controller: _broughtByController,
                                      decoration: InputDecoration(
                                        labelText: l10n?.translate('noteOptional') ??
                                            'Izoh (ixtiyoriy)',
                                        border: const OutlineInputBorder(),
                                        hintText: l10n?.translate('noteHint') ??
                                            'Masalan: kim olib keldi, qayerdan keldi',
                                        prefixIcon: const Icon(Icons.note_alt),
                                      ),
                                      textCapitalization: TextCapitalization.sentences,
                                      onSubmitted: (_) => _addPart(),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    _nameController.clear();
                                    _broughtByController.clear();
                                    _contactNameController.clear();
                                    _contactPhoneController.clear();
                                    _quantityController.clear();
                                    _minQuantityController.clear();
                                    _selectedImage = null;
                                    Navigator.pop(context);
                                  },
                                  child: Text(l10n?.translate('cancel') ?? 'Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: _addPart,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(l10n?.translate('add') ?? 'Add'),
                                ),
                              ],
                            );
                            },
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.playlist_add),
                        title: Text(l10n?.translate('batchAddParts') ?? 'Batch Add Parts'),
                        onTap: () {
                          Navigator.pop(context);
                          _showBatchAddDialog();
                        },
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(l10n?.translate('addPart') ?? 'Add Part'),
              )
              : null,
        );
      },
    );
  }

  /// Rasm placeholder widget
  Widget _buildImagePlaceholder(Color statusColor) {
    final l10n = AppLocalizations.of(context);
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l10n?.translate('tapToAdd') ?? 'Tap to add',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: statusColor.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: overlapsContent ? 1 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
