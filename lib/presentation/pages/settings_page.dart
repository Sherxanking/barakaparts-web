/// SettingsPage - App settings and configuration page
/// 
/// This page allows users to:
/// - Change app language (Uzbek, Russian, English)
/// - View app information
/// 
/// The language change is saved to SharedPreferences and persists across app restarts.
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../data/services/language_service.dart';
import '../../main.dart';
import '../pages/home_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _selectedLanguage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
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
                          subtitle: const Text('Version 1.0.0'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
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

