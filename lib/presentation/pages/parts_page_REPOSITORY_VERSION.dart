/// PartsPage - Repository Pattern Version
/// 
/// Bu versiya Repository pattern dan foydalanadi va Supabase dan ma'lumot oladi.

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
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _minQuantityController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // State
  SortOption? _selectedSortOption;
  bool _showLowStockOnly = false;
  File? _selectedImage;
  String? _currentEditImagePath;
  
  // Data state
  List<Part> _parts = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Stream subscription
  StreamSubscription<Either<Failure, List<Part>>>? _partsStreamSubscription;

  late final VoidCallback _searchListener;

  @override
  void initState() {
    super.initState();
    _searchListener = () => setState(() {});
    _searchController.addListener(_searchListener);
    _loadParts();
    _listenToParts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_searchListener);
    _nameController.dispose();
    _quantityController.dispose();
    _minQuantityController.dispose();
    _searchController.dispose();
    _partsStreamSubscription?.cancel();
    super.dispose();
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
        _showSnackBar('Failed to load parts: ${failure.message}', Colors.red);
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
  /// FIX: Added proper error handling and mounted checks
  /// WHY: Prevents crashes and ensures stream subscription is properly handled
  void _listenToParts() {
    _partsStreamSubscription = _partRepository.watchParts().listen(
      (result) {
        if (!mounted) return;
        result.fold(
          (failure) {
            // Error bo'lsa, log qilamiz va error state ni yangilaymiz
            debugPrint('Stream error: ${failure.message}');
            setState(() {
              _errorMessage = failure.message;
            });
          },
          (parts) {
            // Ma'lumotlar yangilandi
            if (mounted) {
              setState(() {
                _parts = parts;
                _errorMessage = null; // Clear error on success
              });
            }
          },
        );
      },
      onError: (error) {
        debugPrint('Stream error: $error');
        if (mounted) {
          setState(() {
            _errorMessage = 'Stream error: $error';
          });
        }
      },
      cancelOnError: false, // Don't cancel on error, keep listening
    );
  }

  /// Kam qolgan qismlarni olish
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

    final part = Part(
      id: partId,
      name: _nameController.text.trim(),
      quantity: quantity,
      minQuantity: minQuantity,
      imagePath: imagePath,
      createdAt: DateTime.now(),
    );

    final result = await _partRepository.createPart(part);
    
    result.fold(
      (failure) {
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
  }

  /// Qismni yangilash
  Future<void> _updatePart(Part part) async {
    final result = await _partRepository.updatePart(part);
    
    result.fold(
      (failure) {
        if (mounted) {
          _showSnackBar('Failed to update part: ${failure.message}', Colors.red);
        }
      },
      (updatedPart) {
        if (mounted) {
          _showSnackBar('Part updated successfully', Colors.green);
          Navigator.pop(context);
        }
      },
    );
  }

  /// Qismni o'chirish
  Future<void> _deletePart(Part part) async {
    final result = await _partRepository.deletePart(part.id);
    
    result.fold(
      (failure) {
        if (mounted) {
          _showSnackBar('Failed to delete part: ${failure.message}', Colors.red);
        }
      },
      (_) {
        if (mounted) {
          _showSnackBar('Part deleted successfully', Colors.green);
        }
      },
    );
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

  // ... (build metod va boshqa UI kodlar keyinroq qo'shiladi)
  
  @override
  Widget build(BuildContext context) {
    // TODO: UI kodlarini qo'shish
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : const Center(child: Text('Parts list will be here')),
    );
  }
}

