/// App Constants
/// 
/// WHY: Centralized constants file for Supabase URL and keys
/// All Supabase-related constants are stored here to avoid deprecated getter usage
/// and ensure single source of truth for configuration values.

import '../config/env_config.dart';

/// Supabase Configuration Constants
/// 
/// These constants are loaded from environment variables (.env file)
/// and provide a centralized way to access Supabase configuration
/// without using deprecated client getters.
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  /// Supabase Project URL
  /// 
  /// WHY: Replaces deprecated `client.supabaseUrl` getter
  /// Loaded from .env file via EnvConfig
  static String get supabaseUrl {
    try {
      return EnvConfig.supabaseUrl;
    } catch (e) {
      throw Exception(
        'SUPABASE_URL not configured. Please check your .env file.\n'
        'Expected format: SUPABASE_URL=https://your-project.supabase.co'
      );
    }
  }

  /// Supabase Anonymous Key (Public Key)
  /// 
  /// WHY: Replaces deprecated `client.supabaseKey` getter
  /// Loaded from .env file via EnvConfig
  /// ⚠️ SECURITY: This is the ANON key, safe for client-side use
  static String get supabaseAnonKey {
    try {
      return EnvConfig.supabaseAnonKey;
    } catch (e) {
      throw Exception(
        'SUPABASE_ANON_KEY not configured. Please check your .env file.\n'
        'Expected format: SUPABASE_ANON_KEY=your-anon-key-here'
      );
    }
  }

  /// OAuth Redirect URL for Google Sign-In
  /// 
  /// WHY: Centralized redirect URL configuration for OAuth flows
  /// Format: {SUPABASE_URL}/auth/v1/callback
  static String get oauthRedirectUrl {
    return '$supabaseUrl/auth/v1/callback';
  }

  /// Deep Link URL for Mobile Apps (Android/iOS)
  /// 
  /// WHY: Custom URL scheme for mobile OAuth redirects
  /// Updated to match package name: com.probaraka.barakaparts
  /// Format: com.probaraka.barakaparts://login-callback
  static String get mobileDeepLinkUrl {
    return 'com.probaraka.barakaparts://login-callback';
  }

  /// App Environment
  static String get appEnv => EnvConfig.appEnv;

  /// Is Production Mode
  static bool get isProduction => EnvConfig.isProduction;

  /// Is Development Mode
  static bool get isDevelopment => EnvConfig.isDevelopment;
}

