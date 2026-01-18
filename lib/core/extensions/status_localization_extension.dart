/// Status Localization Extension
/// 
/// Provides localized status strings without manual capitalization.
/// Capitalization comes from translation files, not code.
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

extension StatusLocalization on String {
  /// Get localized status string
  /// 
  /// Maps status values (available, unavailable, pending, completed, etc.)
  /// to their localized translations.
  /// 
  /// Capitalization is handled by translation files, not code.
  String localizedStatus(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return this;
    
    final statusKey = toLowerCase().trim();
    
    switch (statusKey) {
      case 'available':
        return l10n.translate('available');
      case 'unavailable':
        return l10n.translate('unavailable');
      case 'pending':
        return l10n.translate('pending');
      case 'completed':
        return l10n.translate('completed');
      case 'cancelled':
      case 'canceled':
        return l10n.translate('cancelled');
      case 'rejected':
        return l10n.translate('rejected');
      case 'in_progress':
      case 'inprogress':
        return l10n.translate('inProgress');
      case 'new':
        return l10n.translate('new');
      default:
        // Fallback: return original if no translation found
        return this;
    }
  }
}























