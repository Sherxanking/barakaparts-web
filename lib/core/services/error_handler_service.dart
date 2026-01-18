/// Error Handler Service
/// 
/// Global error handling va logging uchun service
/// Production'da barcha xatoliklarni catch qiladi va log qiladi

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../errors/failures.dart';

class ErrorHandlerService {
  static ErrorHandlerService? _instance;
  static ErrorHandlerService get instance {
    _instance ??= ErrorHandlerService._();
    return _instance!;
  }
  
  ErrorHandlerService._();

  /// Global error handler - Flutter xatoliklarini catch qiladi
  void handleFlutterError(FlutterErrorDetails details) {
    // Production'da console'ga yozish
    FlutterError.presentError(details);
    
    // Log qilish (production'da Sentry yoki boshqa service'ga yuborish mumkin)
    _logError(
      error: details.exception,
      stackTrace: details.stack,
      context: details.context?.toString(),
      information: details.informationCollector?.call(),
    );
  }

  /// Zone error handler - async xatoliklarini catch qiladi
  void handleZoneError(Object error, StackTrace stackTrace) {
    debugPrint('❌ Zone Error: $error');
    debugPrint('   Stack: $stackTrace');
    
    _logError(
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Failure'ni user-friendly message'ga o'zgartirish
  /// Oson tilda, tushunarli xatolik xabarlari
  String getErrorMessage(Failure failure) {
    // SECURITY: Maxfiy ma'lumotlarni filtrlash
    String sanitizeMessage(String message) {
      String sanitized = message;
      
      // JWT tokenlar
      sanitized = sanitized.replaceAll(
        RegExp(r'eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+', caseSensitive: false),
        '[TOKEN]',
      );
      
      // API keylar (uzun alphanumeric strings)
      sanitized = sanitized.replaceAll(
        RegExp(r'\b[a-zA-Z0-9]{32,}\b'),
        '[KEY]',
      );
      
      // URL parametrlar
      sanitized = sanitized.replaceAll(
        RegExp(r'[?&](api_key|apikey|key|token|secret|password|auth)=[^&\s]+', caseSensitive: false),
        '[PARAM]',
      );
      
      // Supabase URL'lar
      sanitized = sanitized.replaceAll(
        RegExp(r'https?://[a-zA-Z0-9-]+\.supabase\.co/[^\s]+', caseSensitive: false),
        '[URL]',
      );
      
      return sanitized;
    }
    
    // Network xatoliklari
    if (failure is NetworkFailure) {
      return 'Internet aloqasi yo\'q. Internetni tekshiring va qayta urinib ko\'ring.';
    }
    
    // Server xatoliklari
    if (failure is ServerFailure) {
      final message = failure.message.toLowerCase();
      
      // Internet aloqasi
      if (message.contains('network') || 
          message.contains('connection') ||
          message.contains('timeout') ||
          message.contains('socketexception') ||
          message.contains('failed host lookup') ||
          message.contains('no internet')) {
        return 'Internet aloqasi yo\'q. Internetni tekshiring va qayta urinib ko\'ring.';
      }
      
      // Ruxsat xatoliklari
      if (message.contains('permission denied') ||
          message.contains('row-level security') ||
          message.contains('policy') ||
          message.contains('unauthorized') ||
          message.contains('forbidden')) {
        return 'Ruxsat yo\'q. Administrator bilan bog\'laning.';
      }
      
      // Ma'lumotlar bazasi xatoliklari
      if (message.contains('postgresexception') ||
          message.contains('postgrest') ||
          message.contains('database') ||
          message.contains('sql') ||
          message.contains('constraint')) {
        return 'Ma\'lumotlar bazasi xatosi. Qayta urinib ko\'ring.';
      }
      
      // Not found xatoliklari
      if (message.contains('not found') ||
          message.contains('does not exist') ||
          message.contains('404')) {
        return 'Ma\'lumot topilmadi.';
      }
      
      // Duplicate/Already exists
      if (message.contains('duplicate') ||
          message.contains('already exists') ||
          message.contains('unique constraint')) {
        return 'Bu ma\'lumot allaqachon mavjud.';
      }
      
      // Generic server error
      return 'Server xatosi. Qayta urinib ko\'ring.';
    }
    
    // Autentifikatsiya xatoliklari
    if (failure is AuthFailure) {
      final message = failure.message.toLowerCase();
      
      // Noto'g'ri email/parol
      if (message.contains('invalid') || 
          message.contains('wrong password') ||
          message.contains('invalid login') ||
          message.contains('invalid credentials')) {
        // Agar xabarda ro'yxatdan o'tish haqida eslatma bo'lsa, uni ko'rsatish
        if (message.contains('ro\'yxatdan') || message.contains('register')) {
          return message; // To'g'ridan-to'g'ri ko'rsatish
        }
        return 'Noto\'g\'ri email yoki parol. Email va parolni tekshiring yoki ro\'yxatdan o\'ting.';
      }
      
      // Email tasdiqlanmagan
      if (message.contains('email not confirmed') || 
          message.contains('email_not_verified') ||
          message.contains('email not verified')) {
        return 'Email tasdiqlanmagan. Email\'ingizni tekshiring va tasdiqlang.';
      }
      
      // User topilmadi
      if (message.contains('user not found') ||
          message.contains('no account')) {
        return 'Bu email bilan foydalanuvchi topilmadi. Ro\'yxatdan o\'ting.';
      }
      
      // Juda ko'p urinishlar
      if (message.contains('too many requests') ||
          message.contains('rate limit')) {
        return 'Juda ko\'p urinishlar. Bir necha daqiqa kutib, qayta urinib ko\'ring.';
      }
      
      // Email allaqachon ro'yxatdan o'tgan
      if (message.contains('already registered') ||
          message.contains('already exists') ||
          message.contains('email already')) {
        return 'Bu email allaqachon ro\'yxatdan o\'tgan. Kirish sahifasiga o\'ting.';
      }
      
      // Parol juda zaif
      if (message.contains('password') && 
          (message.contains('weak') || message.contains('short'))) {
        return 'Parol juda zaif. Kamida 6 belgi bo\'lishi kerak.';
      }
      
      // Registration disabled
      if (message.contains('signup disabled') ||
          message.contains('registration disabled')) {
        return 'Ro\'yxatdan o\'tish hozircha o\'chirilgan. Administrator bilan bog\'laning.';
      }
      
      // Generic auth error
      return 'Kirish xatosi. Qayta urinib ko\'ring.';
    }
    
    // Validation xatoliklari
    if (failure is ValidationFailure) {
      // Validation xatoliklari odatda user-friendly bo'ladi
      return failure.message;
    }
    
    // Permission xatoliklari
    if (failure is PermissionFailure) {
      return 'Ruxsat yo\'q. Bu amalni bajarish uchun ruxsatingiz yetarli emas.';
    }
    
    // Unknown xatoliklar
    if (failure is UnknownFailure) {
      return 'Kutilmagan xatolik yuz berdi. Qayta urinib ko\'ring.';
    }
    
    // Cache xatoliklari
    if (failure is CacheFailure) {
      return 'Ma\'lumotlarni saqlashda xatolik. Qayta urinib ko\'ring.';
    }
    
    // Default - maxfiy ma'lumotlarni filtrlash
    return sanitizeMessage(failure.message);
  }

  /// Error'ni log qilish
  /// SECURITY: Production'da maxfiy ma'lumotlarni filtrlash
  void _logError({
    required Object error,
    StackTrace? stackTrace,
    String? context,
    Iterable<DiagnosticsNode>? information,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    
    // SECURITY: Production'da maxfiy ma'lumotlarni filtrlash
    String sanitizeForLog(String text) {
      if (kReleaseMode) {
        // Production'da maxfiy ma'lumotlarni olib tashlash
        return text
            .replaceAll(RegExp(r'eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+'), '[TOKEN]')
            .replaceAll(RegExp(r'\b[a-zA-Z0-9]{32,}\b'), '[KEY]')
            .replaceAll(RegExp(r'[?&](api_key|apikey|key|token|secret|password|auth)=[^&\s]+', caseSensitive: false), '[PARAM]')
            .replaceAll(RegExp(r'https?://[a-zA-Z0-9-]+\.supabase\.co/[^\s]+'), '[SUPABASE_URL]');
      }
      return text; // Development'da to'liq log
    }
    
    debugPrint('═══════════════════════════════════════');
    debugPrint('❌ ERROR [$timestamp]');
    debugPrint('═══════════════════════════════════════');
    debugPrint('Error: ${sanitizeForLog(error.toString())}');
    if (stackTrace != null) {
      debugPrint('Stack Trace:');
      debugPrint(sanitizeForLog(stackTrace.toString()));
    }
    if (context != null) {
      debugPrint('Context: ${sanitizeForLog(context)}');
    }
    if (information != null && information.isNotEmpty) {
      debugPrint('Information:');
      for (final info in information) {
        debugPrint('  ${sanitizeForLog(info.toStringDeep())}');
      }
    }
    debugPrint('═══════════════════════════════════════');
    
    // Production'da bu yerda Sentry yoki boshqa logging service'ga yuborish mumkin
    // if (kReleaseMode) {
    //   Sentry.captureException(error, stackTrace: stackTrace);
    // }
  }

  /// User-friendly error dialog ko'rsatish
  Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) async {
    if (!context.mounted) return;
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Yopish'),
          ),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAction();
              },
              child: Text(actionText),
            ),
        ],
      ),
    );
  }

  /// SnackBar bilan error ko'rsatish
  void showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Yopish',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

