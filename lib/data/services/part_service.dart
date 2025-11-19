/// PartService - Part bilan ishlash uchun business logic
/// 
/// Bu service part CRUD operatsiyalarini, qidiruv, filtrlash 
/// va tartiblash funksiyalarini boshqaradi. Shuningdek, 
/// stock management funksiyalarini ham boshqaradi.
import '../models/part_model.dart';
import 'hive_box_service.dart';

class PartService {
  final HiveBoxService _boxService = HiveBoxService();

  /// Barcha partlarni olish
  /// FIX: Xavfsiz box kirish - xatolik bo'lsa bo'sh ro'yxat qaytarish
  List<PartModel> getAllParts() {
    try {
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

  /// Part qo'shish
  /// FIX: Xatolikni tutish va xavfsiz qo'shish
  Future<bool> addPart(PartModel part) async {
    try {
      await _boxService.partsBox.add(part);
      return true;
    } catch (e) {
      // Xatolik bo'lsa false qaytarish
      return false;
    }
  }

  /// Part yangilash
  /// FIX: Xatolikni tutish va xavfsiz yangilash
  Future<bool> updatePart(PartModel part) async {
    try {
      await part.save();
      return true;
    } catch (e) {
      // Xatolik bo'lsa false qaytarish
      return false;
    }
  }

  /// Part o'chirish
  /// FIX: Index tekshiruvi va xatolikni tutish
  Future<bool> deletePart(int index) async {
    try {
      if (index >= 0 && index < _boxService.partsBox.length) {
        await _boxService.partsBox.deleteAt(index);
        return true;
      }
      return false;
    } catch (e) {
      // Xatolik bo'lsa false qaytarish
      return false;
    }
  }

  /// Part miqdorini oshirish
  /// FIX: Xatolikni tutish va xavfsiz yangilash
  Future<bool> increaseQuantity(String partId, int amount) async {
    try {
      final part = getPartById(partId);
      if (part != null) {
        part.quantity += amount;
        await part.save();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Part miqdorini kamaytirish
  /// FIX: Xatolikni tutish va xavfsiz yangilash
  Future<bool> decreaseQuantity(String partId, int amount) async {
    try {
      final part = getPartById(partId);
      if (part != null) {
        part.quantity = (part.quantity - amount).clamp(0, double.infinity).toInt();
        await part.save();
        return true;
      }
      return false;
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

