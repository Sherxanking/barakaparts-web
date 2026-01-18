/// SettingsPage - App settings and configuration page
/// 
/// This page allows users to:
/// - Change app language (Uzbek, Russian, English)
/// - View app information
/// 
/// The language change is saved to SharedPreferences and persists across app restarts.
/// Settings Page - App settings and logout
/// 
/// WHY: Updated to use new auth/login_page path and removed duplicate imports

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../data/services/language_service.dart';
import '../../main.dart';
import '../pages/home_page.dart';
import 'auth/login_page.dart';
import '../../core/services/auth_state_service.dart';
import '../../core/services/error_handler_service.dart';
import '../../infrastructure/datasources/supabase_user_datasource.dart';
import '../../infrastructure/repositories/user_repository_impl.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/user.dart' as domain;
import '../../domain/entities/user.dart' as domain;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _selectedLanguage;
  bool _isLoading = true;
  late final UserRepository _userRepository;
  domain.User? _currentUser; // FIX: Store current user in state for web compatibility
  String _appVersionLabel = 'Version ...';

  @override
  void initState() {
    super.initState();
    _userRepository = UserRepositoryImpl(
      datasource: SupabaseUserDatasource(),
    );
    _loadCurrentLanguage();
    _loadAppVersion();
    
    // FIX: Listen to auth state changes for web compatibility
    _currentUser = AuthStateService().currentUser;
    AuthStateService().onAuthStateChange((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }
  
  @override
  void dispose() {
    // Cleanup callback (optional, but good practice)
    super.dispose();
  }

  /// Logout qilish
  Future<void> _handleLogout() async {
    // Tasdiqlash dialogi
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chiqish'),
        content: const Text('Haqiqatan ham chiqmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Chiqish', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    // Logout qilish
    final result = await _userRepository.signOut();
    
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout xatolik: ${ErrorHandlerService.instance.getErrorMessage(failure)}'),
            backgroundColor: Colors.red,
          ),
        );
      },
      (_) {
        // FIX: Use global auth state service for logout
        // WHY: Ensures consistent auth state across app
        AuthStateService().signOut();
        // Navigate to login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false, // Barcha oldingi sahifalarni o'chirish
        );
      },
    );
  }

  /// Load the currently saved language preference
  Future<void> _loadCurrentLanguage() async {
    final savedLanguage = await LanguageService.getSavedLanguage();
    final currentLocale = AppLocalizations.of(context)?.locale;
    
    setState(() {
      _selectedLanguage = savedLanguage ?? currentLocale?.languageCode ?? 'en';
      _isLoading = false;
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersionLabel = 'Version ${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      // Keep default label on failure
    }
  }

  /// App tilini o'zgartirish va sozlamani saqlash
  /// 
  /// Bu metod tilni o'zgartirib, SharedPreferences'ga saqlaydi
  /// va app'ni real-time yangilaydi.
  Future<void> _changeLanguage(String languageCode) async {
    if (_selectedLanguage == languageCode) return;
    
    setState(() {
      _selectedLanguage = languageCode;
    });
    
    await LanguageService.setLanguage(languageCode);
    
    // App tilini real-time yangilash
    if (mounted) {
      // MaterialApp'ga kirish uchun root context ishlatish
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      final appState = rootContext.findAncestorStateOfType<MyAppState>();
      if (appState != null) {
        appState.changeLocale(Locale(languageCode));
      } else {
        // Agar topilmasa, app'ni qayta yuklash
        Navigator.of(context).pop();
        // Kichik kechikish bilan app yangilanadi
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Current User Info Section
                if (_currentUser != null)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    _currentUser!.name.isNotEmpty
                                        ? _currentUser!.name[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentUser!.name,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    if (_currentUser!.email != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _currentUser!.email!,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.grey[600],
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(_currentUser!.role).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _getRoleColor(_currentUser!.role),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getRoleIcon(_currentUser!.role),
                                            size: 16,
                                            color: _getRoleColor(_currentUser!.role),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _getRoleLabel(_currentUser!.role),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _getRoleColor(_currentUser!.role),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_currentUser!.phone != null && _currentUser!.phone!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 20,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _currentUser!.phone!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (_currentUser != null) const SizedBox(height: 16),
                // Language Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('language'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        // Uzbek
                        _LanguageOption(
                          languageCode: 'uz',
                          languageName: AppLocalizations.supportedLanguages['uz']!,
                          isSelected: _selectedLanguage == 'uz',
                          onTap: () => _changeLanguage('uz'),
                        ),
                        const Divider(),
                        // Russian
                        _LanguageOption(
                          languageCode: 'ru',
                          languageName: AppLocalizations.supportedLanguages['ru']!,
                          isSelected: _selectedLanguage == 'ru',
                          onTap: () => _changeLanguage('ru'),
                        ),
                        const Divider(),
                        // English
                        _LanguageOption(
                          languageCode: 'en',
                          languageName: AppLocalizations.supportedLanguages['en']!,
                          isSelected: _selectedLanguage == 'en',
                          onTap: () => _changeLanguage('en'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // App Info Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('appSettings'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('Baraka Parts'),
                          subtitle: Text(_appVersionLabel),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Logout Section
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Chiqish',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: _handleLogout,
                  ),
                ),
              ],
            ),
    );
  }

  /// Get role color
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'boss':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      case 'worker':
        return Colors.green;
      case 'supplier':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Get role icon
  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'boss':
        return Icons.verified_user;
      case 'manager':
        return Icons.supervisor_account;
      case 'worker':
        return Icons.person;
      case 'supplier':
        return Icons.local_shipping;
      default:
        return Icons.person_outline;
    }
  }

  /// Get role label
  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'boss':
        return 'Boss';
      case 'manager':
        return 'Manager';
      case 'worker':
        return 'Worker';
      case 'supplier':
        return 'Supplier';
      default:
        return role.toUpperCase();
    }
  }
}

/// Language option widget for settings page
class _LanguageOption extends StatelessWidget {
  final String languageCode;
  final String languageName;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.languageCode,
    required this.languageName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(languageName),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

