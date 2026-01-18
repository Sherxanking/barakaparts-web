/// Environment Configuration
/// 
/// Xavfsiz environment variables o'qish uchun.
/// .env fayldan ma'lumotlarni o'qiydi.

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class EnvConfig {
  /// .env faylni yuklash
  static Future<void> load() async {
    try {
      // Flutter da env fayl assets/ papkasida bo'lishi kerak
      // va pubspec.yaml da assets qo'shilishi kerak
      await dotenv.load(fileName: 'assets/env');
      debugPrint('✅ env fayl assets/env dan yuklandi');
    } catch (e) {
      // Agar assets/env topilmasa, root .env ni sinab ko'ramiz
      try {
        await dotenv.load(fileName: '.env');
        debugPrint('✅ .env fayl root dan yuklandi');
      } catch (e2) {
        // .env fayl topilmasa, xatolik beradi
        debugPrint('⚠️ .env fayl yuklanmadi: $e2');
        debugPrint('📝 Eslatma: env fayl assets/env yoki root da bo\'lishi kerak');
        debugPrint('📝 pubspec.yaml da assets qo\'shilganini tekshiring');
        // Exception throw qilmaymiz - Supabase initialize qilishda tekshiriladi
      }
    }
  }

  /// Supabase URL olish
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('❌ SUPABASE_URL .env faylda topilmadi');
    }
    return url;
  }

  /// Supabase Anon Key olish (frontend uchun)
  /// ⚠️ Service role key bu yerda EMAS!
  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('❌ SUPABASE_ANON_KEY .env faylda topilmadi');
    }
    return key;
  }

  /// Backend API URL (agar mavjud bo'lsa)
  static String? get backendApiUrl {
    return dotenv.env['BACKEND_API_URL'];
  }

  /// App Environment (development/production)
  static String get appEnv {
    return dotenv.env['APP_ENV'] ?? 'development';
  }

  /// Production mode tekshirish
  static bool get isProduction {
    return appEnv == 'production';
  }

  /// Development mode tekshirish
  static bool get isDevelopment {
    return appEnv == 'development';
  }
}

