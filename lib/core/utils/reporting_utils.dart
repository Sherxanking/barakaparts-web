import 'package:intl/intl.dart';
import '../../domain/entities/part.dart';

/// Utility class for generating inventory reports
class ReportingUtils {
  /// Formats a list of low stock parts into a readable text report
  static String formatLowStockReport(List<Part> lowStockParts) {
    final now = DateTime.now();
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(now);
    
    if (lowStockParts.isEmpty) {
      return "📦 BarakaParts: Hozirda kam qolgan tovarlar mavjud emas.\n📅 Sana: $dateStr";
    }

    final buffer = StringBuffer();
    buffer.writeln("⚠️ *BARAKAPARTS: KAM QOLGAN TOVARLAR* ⚠️");
    buffer.writeln("📅 Sana: $dateStr");
    buffer.writeln("-----------------------------------------");
    buffer.writeln("");
    
    for (int i = 0; i < lowStockParts.length; i++) {
      final part = lowStockParts[i];
      buffer.writeln("${i + 1}. *${part.name}*");
      buffer.writeln("   🔹 Joriy miqdor: ${part.quantity} dona");
      buffer.writeln("   🔹 Kamida bo'lishi kerak: ${part.minQuantity} dona");
      if (part.broughtBy != null) {
        buffer.writeln("   👤 Olib keluvchi: ${part.broughtBy}");
      }
      buffer.writeln("");
    }
    
    buffer.writeln("-----------------------------------------");
    buffer.writeln("📢 Iltimos, ushbu tovarlarni to'ldirish choralarini ko'ring.");
    
    return buffer.toString();
  }
}
