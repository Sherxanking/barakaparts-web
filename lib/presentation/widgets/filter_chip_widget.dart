/// FilterChipWidget - Filtrlash uchun reusable chip widget
/// 
/// Bu widget filtrlash variantlarini ko'rsatish uchun ishlatiladi.
/// Material Design 3 FilterChip komponenti asosida.
import 'package:flutter/material.dart';

class FilterChipWidget extends StatelessWidget {
  /// Chip label
  final String label;
  
  /// Chip tanlanganligi
  final bool selected;
  
  /// Chip tanlanganda chaqiriladigan callback
  final ValueChanged<bool> onSelected;
  
  /// Icon (ixtiyoriy)
  final IconData? icon;

  const FilterChipWidget({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      avatar: icon != null ? Icon(icon, size: 18) : null,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }
}

