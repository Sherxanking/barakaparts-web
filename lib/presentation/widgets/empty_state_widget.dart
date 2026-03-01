/// EmptyStateWidget - Bo'sh holatni ko'rsatish uchun reusable widget
/// 
/// Bu widget ma'lumotlar bo'sh bo'lganda foydalanuvchiga 
/// ko'rsatiladigan standart UI komponenti.
import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  /// Asosiy icon
  final IconData icon;
  
  /// Asosiy matn
  final String title;
  
  /// Qo'shimcha tavsif
  final String? subtitle;
  
  /// Action button (ixtiyoriy)
  final Widget? actionButton;

  const EmptyStateWidget({
    super.key,
    this.icon = Icons.inbox,
    required this.title,
    this.subtitle,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with a soft background circle
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 80,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 32),
            // Bold title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              // Subtle subtitle
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5, // Line height for readability
                ),
              ),
            ],
            if (actionButton != null) ...[
              const SizedBox(height: 32),
              actionButton!,
            ],
          ],
        ),
      ),
    );
  }
}

