/// SortDropdownWidget - Tartiblash uchun reusable dropdown widget
/// 
/// Bu widget ma'lumotlarni turli usullar bilan tartiblash imkonini beradi.
/// Material Design 3 DropdownButton asosida.
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Tartiblash variantlari
enum SortOption {
  nameAsc('nameAsc', true),
  nameDesc('nameDesc', false),
  dateAsc('dateAsc', true),
  dateDesc('dateDesc', false),
  quantityAsc('quantityAsc', true),
  quantityDesc('quantityDesc', false);

  final String translationKey;
  final bool ascending;
  const SortOption(this.translationKey, this.ascending);
  
  /// Get localized label
  String getLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return l10n?.translate(translationKey) ?? translationKey;
  }
}

class SortDropdownWidget extends StatelessWidget {
  /// Tanlangan tartiblash variant
  final SortOption? selectedOption;
  
  /// Tartiblash o'zgarganda chaqiriladigan callback
  final ValueChanged<SortOption> onChanged;
  
  /// Ko'rsatiladigan variantlar ro'yxati
  final List<SortOption> options;

  const SortDropdownWidget({
    super.key,
    this.selectedOption,
    required this.onChanged,
    this.options = const [
      SortOption.nameAsc,
      SortOption.nameDesc,
      SortOption.dateAsc,
      SortOption.dateDesc,
    ],
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<SortOption>(
      value: selectedOption,
      decoration: InputDecoration(
        labelText: l10n?.translate('sortBy') ?? 'Sort by',
        prefixIcon: const Icon(Icons.sort),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: options.map((option) {
        return DropdownMenuItem(
          value: option,
          child: Text(option.getLabel(context)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

