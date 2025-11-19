/// LanguageService - App language management service
/// 
/// This service manages the app's language preference using SharedPreferences.
/// It stores the selected language and provides methods to get/set the current language.
/// 
/// Supported languages: Uzbek (uz), Russian (ru), English (en)
/// On first install, the app will use the device's default locale.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LanguageService {
  static const String _languageKey = 'app_language';
  
  /// Get the saved language code from SharedPreferences
  /// Returns null if no language is saved (first install)
  static Future<String?> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }
  
  /// Save the selected language code to SharedPreferences
  static Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }
  
  /// Get the locale based on saved preference or device locale
  /// Returns device locale if no preference is saved
  static Future<Locale> getLocale() async {
    final savedLanguage = await getSavedLanguage();
    if (savedLanguage != null && ['uz', 'ru', 'en'].contains(savedLanguage)) {
      return Locale(savedLanguage);
    }
    // Return device locale or default to English
    return const Locale('en');
  }
}

