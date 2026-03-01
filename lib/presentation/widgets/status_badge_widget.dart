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
  
  /// Ixcham rejim
  final bool compact;
  
  /// Status rangini aniqlash
  final Color? color;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.color,
    this.compact = false,
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
      case 'partially_completed':
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
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8, 
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(color: statusColor, width: 1),
      ),
      constraints: BoxConstraints(
        maxWidth: compact ? 70 : 80,
      ),
      child: Text(
        localizedStatus,
        style: TextStyle(
          color: statusColor,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}