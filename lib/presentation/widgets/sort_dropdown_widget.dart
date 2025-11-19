/// SortDropdownWidget - Tartiblash uchun reusable dropdown widget
/// 
/// Bu widget ma'lumotlarni turli usullar bilan tartiblash imkonini beradi.
/// Material Design 3 DropdownButton asosida.
import 'package:flutter/material.dart';

/// Tartiblash variantlari
enum SortOption {
  nameAsc('Name (A-Z)', true),
  nameDesc('Name (Z-A)', false),
  dateAsc('Date (Oldest)', true),
  dateDesc('Date (Newest)', false),
  quantityAsc('Quantity (Low)', true),
  quantityDesc('Quantity (High)', false);

  final String label;
  final bool ascending;
  const SortOption(this.label, this.ascending);
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
    return DropdownButtonFormField<SortOption>(
      value: selectedOption,
      decoration: InputDecoration(
        labelText: 'Sort by',
        prefixIcon: const Icon(Icons.sort),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: options.map((option) {
        return DropdownMenuItem(
          value: option,
          child: Text(option.label),
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

