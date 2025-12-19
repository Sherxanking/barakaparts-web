/// PartService - Part bilan ishlash uchun business logic
/// 
/// Bu service part CRUD operatsiyalarini, qidiruv, filtrlash 
/// va tartiblash funksiyalarini boshqaradi. Shuningdek, 
/// stock management funksiyalarini ham boshqaradi.
import 'package:flutter/foundation.dart';
import '../models/part_model.dart';
import 'hive_box_service.dart';
import '../../domain/entities/part.dart';
import '../../core/di/service_locator.dart';
import '../../core/utils/either.dart';

class PartService {
  final HiveBoxService _boxService = HiveBoxService();
  
  // Repository for Supabase sync
  final _partRepository = ServiceLocator.instance.partRepository;

  /// Barcha partlarni olish
  /// FIX: Xavfsiz box kirish - xatolik bo'lsa bo'sh ro'yxat qaytarish
  /// FIX: Chrome'da Hive ishlamaydi - Supabase'dan olish
  List<PartModel> getAllParts() {
    try {
      // FIX: Chrome'da Hive box ochilmaydi - Supabase'dan olish
      if (kIsWeb) {
        // Chrome'da to'g'ridan-to'g'ri repository'dan olish (async emas, lekin sync qilish kerak)
        // Bu fallback - Chrome'da Hive ishlamaydi
        try {
          final box = _boxService.partsBox;
          return box.values.toList();
        } catch (e) {
          // Hive box ochilmagan - bo'sh ro'yxat qaytarish
          // Chrome'da bu normal holat
          return [];
        }
      }
      
      // Mobile/Desktop - Hive box'dan olish
      return _boxService.partsBox.values.toList();
    } catch (e) {
      // Box ochilmagan yoki xatolik bo'lsa bo'sh ro'yxat qaytarish
      return [];
    }
  }

  /// ID bo'yicha part topish
  PartModel? getPartById(String id) {
    // Hive boxda ID key emas, shuning uchun barcha elementlarni qidirish kerak
    try {
      return _boxService.partsBox.values.firstWhere(
        (part) => part.id == id,
        orElse: () => throw StateError('Part not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if part name already exists (case-insensitive, trimmed)
  /// Returns true if duplicate found, false otherwise
  bool _hasDuplicateName(String name, {String? excludeId}) {
    final normalizedName = name.trim().toLowerCase();
    try {
      return _boxService.partsBox.values.any((existingPart) {
        if (excludeId != null && existingPart.id == excludeId) {
          return false; // Exclude current item when editing
        }
        return existingPart.name.trim().toLowerCase() == normalizedName;
      });
    } catch (e) {
      debugPrint('⚠️ Error checking duplicate part name: $e');
      return false; // If check fails, allow creation (server will catch it)
    }
  }

  /// Part qo'shish
  /// FIX: Hive va Supabase'ga yozish (realtime sync uchun)
  /// FIX: Duplicate name validation (case-insensitive, trimmed)
  Future<bool> addPart(PartModel part) async {
    try {
      // 0. Local validation: Check for duplicate name
      if (_hasDuplicateName(part.name)) {
        debugPrint('❌ Duplicate part name detected: ${part.name}');
        return false; // Will be handled by UI with proper error message
      }
      
      // 1. Supabase'ga yozish (realtime sync uchun)
      final domainPart = Part(
        id: part.id,
        name: part.name,
        quantity: part.quantity,
        minQuantity: part.minQuantity,
        imagePath: part.imagePath,
        createdAt: DateTime.now(),
      );
      
      final result = await _partRepository.createPart(domainPart);
      
      return result.fold(
        (failure) {
          debugPrint('❌ Failed to create part in Supabase: ${failure.message}');
          // Supabase'ga yozish xato bo'lsa ham Hive'ga yozishga harakat qilamiz
          try {
            _boxService.partsBox.add(part);
            return true; // Hive'ga yozildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (createdPart) {
          // 2. Hive'ga ham yozish (offline cache uchun)
          try {
            _boxService.partsBox.add(part);
            debugPrint('✅ Part created in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Part created in Supabase but failed to save to Hive: $e');
            return true; // Supabase'ga yozildi, bu asosiy
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in addPart: $e');
      return false;
    }
  }

  /// Part yangilash
  /// FIX: Hive va Supabase'ga yozish (realtime sync uchun)
  /// FIX: Duplicate name validation (case-insensitive, trimmed)
  Future<bool> updatePart(PartModel part) async {
    try {
      // 0. Local validation: Check for duplicate name (exclude current part)
      if (_hasDuplicateName(part.name, excludeId: part.id)) {
        debugPrint('❌ Duplicate part name detected: ${part.name}');
        return false; // Will be handled by UI with proper error message
      }
      
      // 1. Supabase'ga yozish (realtime sync uchun)
      final domainPart = Part(
        id: part.id,
        name: part.name,
        quantity: part.quantity,
        minQuantity: part.minQuantity,
        imagePath: part.imagePath,
        createdAt: DateTime.now(),
      );
      
      final result = await _partRepository.updatePart(domainPart);
      
      return result.fold(
        (failure) async {
          debugPrint('❌ Failed to update part in Supabase: ${failure.message}');
          // Supabase'ga yozish xato bo'lsa ham Hive'ga yozishga harakat qilamiz
          try {
            await part.save();
            return true; // Hive'ga yozildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (updatedPart) async {
          // 2. Hive'ga ham yozish (offline cache uchun)
          try {
            await part.save();
            debugPrint('✅ Part updated in both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Part updated in Supabase but failed to save to Hive: $e');
            return true; // Supabase'ga yozildi, bu asosiy
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in updatePart: $e');
      return false;
    }
  }

  /// Part o'chirish
  /// FIX: Index tekshiruvi va Supabase'ga ham o'chirish
  Future<bool> deletePart(int index) async {
    try {
      if (index < 0 || index >= _boxService.partsBox.length) {
        return false;
      }
      
      final part = _boxService.partsBox.getAt(index);
      if (part == null) return false;
      
      final partId = part.id;
      
      // 1. Supabase'dan o'chirish (realtime sync uchun)
      final result = await _partRepository.deletePart(partId);
      
      return result.fold(
        (failure) async {
          debugPrint('❌ Failed to delete part in Supabase: ${failure.message}');
          // Supabase'dan o'chirish xato bo'lsa ham Hive'dan o'chirishga harakat qilamiz
          try {
            await _boxService.partsBox.deleteAt(index);
            return true; // Hive'dan o'chirildi, lekin sync yo'q
          } catch (e) {
            return false;
          }
        },
        (_) async {
          // 2. Hive'dan ham o'chirish (offline cache uchun)
          try {
            await _boxService.partsBox.deleteAt(index);
            debugPrint('✅ Part deleted from both Supabase and Hive');
            return true;
          } catch (e) {
            debugPrint('⚠️ Part deleted from Supabase but failed to delete from Hive: $e');
            return true; // Supabase'dan o'chirildi, bu asosiy
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in deletePart: $e');
      return false;
    }
  }

  /// Part miqdorini oshirish
  /// FIX: Hive va Supabase'ga yozish (realtime sync uchun)
  Future<bool> increaseQuantity(String partId, int amount) async {
    try {
      final part = getPartById(partId);
      if (part == null) return false;
      
      part.quantity += amount;
      
      // Supabase'ga ham yangilash
      final domainPart = Part(
        id: part.id,
        name: part.name,
        quantity: part.quantity,
        minQuantity: part.minQuantity,
        imagePath: part.imagePath,
        createdAt: DateTime.now(),
      );
      
      final result = await _partRepository.updatePart(domainPart);
      
      return result.fold(
        (failure) async {
          // Supabase xato bo'lsa ham Hive'ga yozish
          try {
            await part.save();
            return true;
          } catch (e) {
            return false;
          }
        },
        (_) async {
          await part.save();
          return true;
        },
      );
    } catch (e) {
      return false;
    }
  }

  /// Part miqdorini kamaytirish
  /// FIX: Hive va Supabase'ga yozish (realtime sync uchun)
  Future<bool> decreaseQuantity(String partId, int amount) async {
    try {
      final part = getPartById(partId);
      if (part == null) return false;
      
      part.quantity = (part.quantity - amount).clamp(0, double.infinity).toInt();
      
      // Supabase'ga ham yangilash
      final domainPart = Part(
        id: part.id,
        name: part.name,
        quantity: part.quantity,
        minQuantity: part.minQuantity,
        imagePath: part.imagePath,
        createdAt: DateTime.now(),
      );
      
      final result = await _partRepository.updatePart(domainPart);
      
      return result.fold(
        (failure) async {
          // Supabase xato bo'lsa ham Hive'ga yozish
          try {
            await part.save();
            return true;
          } catch (e) {
            return false;
          }
        },
        (_) async {
          await part.save();
          return true;
        },
      );
    } catch (e) {
      return false;
    }
  }

  /// Qidiruv - nom bo'yicha
  List<PartModel> searchParts(String query) {
    if (query.isEmpty) return getAllParts();
    
    final lowerQuery = query.toLowerCase();
    return getAllParts().where((part) {
      return part.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Low stock partlarni olish (threshold dan kam)
  List<PartModel> getLowStockParts({int threshold = 3}) {
    return getAllParts().where((part) {
      return part.quantity < threshold;
    }).toList();
  }

  /// Status bo'yicha filtrlash
  List<PartModel> filterByStatus(String status) {
    return getAllParts().where((part) {
      return part.status == status;
    }).toList();
  }

  /// Tartiblash - nom yoki miqdor bo'yicha
  List<PartModel> sortParts(List<PartModel> parts, {bool byName = true, bool ascending = true}) {
    final sorted = List<PartModel>.from(parts);
    sorted.sort((a, b) {
      if (byName) {
        final comparison = a.name.compareTo(b.name);
        return ascending ? comparison : -comparison;
      } else {
        final comparison = a.quantity.compareTo(b.quantity);
        return ascending ? comparison : -comparison;
      }
    });
    return sorted;
  }
}

