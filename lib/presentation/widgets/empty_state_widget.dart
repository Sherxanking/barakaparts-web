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
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionButton != null) ...[
              const SizedBox(height: 24),
              actionButton!,
            ],
          ],
        ),
      ),
    );
  }
}

