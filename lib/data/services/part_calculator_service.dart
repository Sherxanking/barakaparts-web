/// PartCalculatorService - Qismlar miqdorini hisoblash va yetishmovchilikni aniqlash
/// 
/// Bu service buyurtma yaratishda qismlar yetishmovchiligini hisoblaydi.
/// Clean Architecture prinsiplariga mos keladi.
import '../models/product_model.dart';
import 'part_service.dart';

/// Qism yetishmovchiligi ma'lumotlari
class PartShortage {
  final String partId;
  final String partName;
  final int required; // Talab qilinadigan miqdor
  final int available; // Mavjud miqdor
  final int shortage; // Yetishmovchilik (required - available)

  PartShortage({
    required this.partId,
    required this.partName,
    required this.required,
    required this.available,
  }) : shortage = (required - available).clamp(0, double.infinity).toInt();

  /// Yetishmovchilik bormi?
  bool get hasShortage => shortage > 0;
}

/// Qismlar hisob-kitob natijasi
class PartsCalculationResult {
  final bool hasShortage;
  final List<PartShortage> shortages;
  final Map<String, int> requiredParts; // partId -> required quantity

  PartsCalculationResult({
    required this.hasShortage,
    required this.shortages,
    required this.requiredParts,
  });
}

class PartCalculatorService {
  final PartService _partService;

  PartCalculatorService(this._partService);

  /// Mahsulot uchun qismlar yetishmovchiligini hisoblash
  /// 
  /// [product] - Hisoblash kerak bo'lgan mahsulot
  /// [orderQuantity] - Buyurtma miqdori
  /// 
  /// Qaytaradi: PartsCalculationResult - yetishmovchilik ma'lumotlari
  PartsCalculationResult calculateShortage(Product product, int orderQuantity) {
    // FIX: Null safety va xavfsiz hisoblash
    if (product.parts.isEmpty || orderQuantity <= 0) {
      return PartsCalculationResult(
        hasShortage: false,
        shortages: [],
        requiredParts: {},
      );
    }

    final Map<String, int> requiredParts = {};
    final List<PartShortage> shortages = [];

    // Har bir qism uchun talab qilinadigan miqdorni hisoblash
    for (var entry in product.parts.entries) {
      final partId = entry.key;
      final qtyPerProduct = entry.value;
      
      // FIX: Null va manfiy qiymatlarni tekshirish
      if (qtyPerProduct <= 0) continue;
      
      final requiredQty = qtyPerProduct * orderQuantity;
      requiredParts[partId] = requiredQty;

      // Qismni topish va mavjud miqdorni olish
      final part = _partService.getPartById(partId);
      if (part == null) {
        // Qism topilmadi - to'liq yetishmovchilik
        shortages.add(PartShortage(
          partId: partId,
          partName: 'Unknown Part',
          required: requiredQty,
          available: 0,
        ));
        continue;
      }

      final availableQty = part.quantity.clamp(0, double.infinity).toInt();

      // Yetishmovchilikni hisoblash
      if (requiredQty > availableQty) {
        shortages.add(PartShortage(
          partId: partId,
          partName: part.name,
          required: requiredQty,
          available: availableQty,
        ));
      }
    }

    return PartsCalculationResult(
      hasShortage: shortages.isNotEmpty,
      shortages: shortages,
      requiredParts: requiredParts,
    );
  }

  /// Qismlar yetarli ekanligini tekshirish (oddiy boolean)
  /// 
  /// [product] - Tekshiriladigan mahsulot
  /// [orderQuantity] - Buyurtma miqdori
  /// 
  /// Qaytaradi: true - yetarli, false - yetishmovchilik bor
  bool hasEnoughParts(Product product, int orderQuantity) {
    final result = calculateShortage(product, orderQuantity);
    return !result.hasShortage;
  }
}

