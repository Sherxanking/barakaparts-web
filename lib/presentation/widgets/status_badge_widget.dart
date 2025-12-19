/// StatusBadgeWidget - Status ko'rsatish uchun reusable badge widget
/// 
/// Bu widget order yoki boshqa entity statusini rangli badge 
/// ko'rinishida ko'rsatadi.
/// 
/// FIX: Uses localized strings - no manual capitalization
import 'package:flutter/material.dart';
import '../../core/extensions/status_localization_extension.dart';

class StatusBadgeWidget extends StatelessWidget {
  /// Status matni
  final String status;
  
  /// Status rangini aniqlash
  final Color? color;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.color,
  });

  /// Status bo'yicha rangni aniqlash
  Color _getStatusColor(BuildContext context) {
    if (color != null) return color!;
    
    switch (status.toLowerCase()) {
      case 'completed':
      case 'available':
        return Colors.green;
      case 'pending':
      case 'in_progress':
        return Colors.orange;
      case 'cancelled':
      case 'unavailable':
        return Colors.red;
      case 'new':
        return Colors.blue;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    // FIX: Use localized status - capitalization from translation files
    final localizedStatus = status.localizedStatus(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Text(
        localizedStatus,
        style: TextStyle(
          color: statusColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

