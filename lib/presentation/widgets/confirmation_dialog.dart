/// ConfirmationDialog - Tasdiqlash dialogi uchun reusable widget
/// 
/// Bu widget o'chirish yoki boshqa muhim operatsiyalar uchun 
/// foydalanuvchidan tasdiqlash so'raydi.
import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  /// Dialog sarlavhasi
  final String title;
  
  /// Dialog matni
  final String message;
  
  /// Tasdiqlash button matni
  final String confirmText;
  
  /// Bekor qilish button matni
  final String cancelText;
  
  /// Tasdiqlash button rangi
  final Color? confirmColor;
  
  /// Icon (ixtiyoriy)
  final IconData? icon;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.confirmColor,
    this.icon,
  });

  /// Dialogni ko'rsatish - static method
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              color: confirmColor ?? Colors.red,
              size: 48,
            )
          : null,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: confirmColor ?? Colors.red,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

