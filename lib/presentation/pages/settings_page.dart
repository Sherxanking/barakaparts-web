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
import 'admin_panel_page.dart';
import 'analytics_page.dart';
import '../../core/services/auth_state_service.dart';
import '../../core/services/error_handler_service.dart';
import '../../infrastructure/datasources/supabase_user_datasource.dart';
import '../../infrastructure/datasources/supabase_client.dart';
import '../../infrastructure/repositories/user_repository_impl.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/user.dart' as domain;
import 'package:supabase_flutter/supabase_flutter.dart';

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
    AuthStateService().onAuthStateChange(_onAuthChanged);
  }

  void _onAuthChanged(domain.User? user) {
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }
  
  @override
  void dispose() {
    // FIX: Remove listener to prevent memory leak and "setState after dispose" error
    AuthStateService().removeAuthStateChangeCallback(_onAuthChanged);
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
        if (mounted) {
          AuthStateService().signOut();
          // Navigate to login
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false, // Barcha oldingi sahifalarni o'chirish
          );
        }
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

  Future<void> _showChangePasswordDialog() async {
    final l10n = AppLocalizations.of(context);
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? errorText;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n?.translate('changePassword') ?? 'Change password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n?.translate('newPassword') ?? 'New password',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n?.translate('confirmPassword') ?? 'Confirm password',
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: Text(l10n?.translate('cancel') ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final newPassword = newPasswordController.text.trim();
                        final confirmPassword = confirmPasswordController.text.trim();
                        if (newPassword.length < 6) {
                          setDialogState(() {
                            errorText = l10n?.translate('passwordTooShort') ??
                                'Password is too short';
                          });
                          return;
                        }
                        if (newPassword != confirmPassword) {
                          setDialogState(() {
                            errorText = l10n?.translate('passwordMismatch') ??
                                'Passwords do not match';
                          });
                          return;
                        }

                        setDialogState(() {
                          errorText = null;
                          isSaving = true;
                        });

                        try {
                          await AppSupabaseClient.instance.client.auth.updateUser(
                            UserAttributes(password: newPassword),
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n?.translate('passwordUpdated') ??
                                      'Password updated successfully',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setDialogState(() {
                              isSaving = false;
                              errorText = l10n?.translate('passwordUpdateFailed') ??
                                  'Failed to update password';
                            });
                          }
                        }
                      },
                child: Text(l10n?.translate('save') ?? 'Save'),
              ),
            ],
          );
        },
      ),
    );

    newPasswordController.dispose();
    confirmPasswordController.dispose();
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
      backgroundColor: Colors.grey[50], // Professional light background
      appBar: AppBar(
        title: Text(l10n.translate('settings') ?? 'Sozlamalar'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Profile Section
                  if (_currentUser != null) _buildProfileHeader(),
                  const SizedBox(height: 24),

                  // 2. Admin/Management Section
                  if (_currentUser != null && (_currentUser!.isManager || _currentUser!.isBoss)) ...[
                    _buildSectionHeader('Boshqaruv'),
                    _buildSettingSection([
                      _buildSettingTile(
                        icon: Icons.admin_panel_settings,
                        iconColor: Colors.blue,
                        title: 'Admin Panel',
                        subtitle: 'Foydalanuvchilarni boshqarish',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminPanelPage()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  // 3. App Settings Section
                  _buildSectionHeader(l10n.translate('appSettings') ?? 'Ilova sozlamalari'),
                  _buildSettingSection([
                    _buildSettingTile(
                      icon: Icons.language,
                      iconColor: Colors.purple,
                      title: l10n.translate('language') ?? 'Til',
                      trailing: Text(
                        AppLocalizations.supportedLanguages[_selectedLanguage] ?? 'English',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      onTap: _showLanguageDialog,
                    ),
                    _buildSettingTile(
                      icon: Icons.lock_outline,
                      iconColor: Colors.orange,
                      title: l10n.translate('changePassword') ?? 'Parolni o\'zgartirish',
                      onTap: _showChangePasswordDialog,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 4. About Section
                  _buildSectionHeader('Ma\'lumotlar'),
                  _buildSettingSection([
                    _buildSettingTile(
                      icon: Icons.info_outline,
                      iconColor: Colors.teal,
                      title: 'Ilova haqida',
                      subtitle: 'Baraka Parts',
                      trailing: Text(_appVersionLabel, style: const TextStyle(fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 5. Logout Section
                  _buildSettingSection([
                    _buildSettingTile(
                      icon: Icons.logout,
                      iconColor: Colors.red,
                      title: 'Tizimdan chiqish',
                      titleColor: Colors.red,
                      showChevron: false,
                      onTap: _handleLogout,
                    ),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingSection(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(tiles.length, (index) {
          return Column(
            children: [
              tiles[index],
              if (index < tiles.length - 1)
                const Divider(height: 1, indent: 56, endIndent: 16),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool showChevron = true,
    Color titleColor = Colors.black87,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: titleColor, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing,
          if (showChevron) ...[
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _currentUser!.name.isNotEmpty ? _currentUser!.name[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser!.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  _getRoleLabel(_currentUser!.role),
                  style: TextStyle(color: _getRoleColor(_currentUser!.role), fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (_currentUser!.email != null) ...[
                  const SizedBox(height: 4),
                  Text(_currentUser!.email!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tilni tanlang', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _LanguageOption(
              languageCode: 'uz',
              languageName: AppLocalizations.supportedLanguages['uz']!,
              isSelected: _selectedLanguage == 'uz',
              onTap: () { Navigator.pop(context); _changeLanguage('uz'); },
            ),
            _LanguageOption(
              languageCode: 'ru',
              languageName: AppLocalizations.supportedLanguages['ru']!,
              isSelected: _selectedLanguage == 'ru',
              onTap: () { Navigator.pop(context); _changeLanguage('ru'); },
            ),
            _LanguageOption(
              languageCode: 'en',
              languageName: AppLocalizations.supportedLanguages['en']!,
              isSelected: _selectedLanguage == 'en',
              onTap: () { Navigator.pop(context); _changeLanguage('en'); },
            ),
          ],
        ),
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

