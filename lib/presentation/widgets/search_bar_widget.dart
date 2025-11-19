/// SearchBarWidget - Qidiruv uchun reusable widget
/// 
/// Bu widget barcha sahifalarda qidiruv funksiyasini ta'minlaydi.
/// TextField va search icon bilan Material Design 3 standartlariga mos.
import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  /// Qidiruv so'zini boshqaruvchi controller
  final TextEditingController controller;
  
  /// Qidiruv so'zi o'zgarganda chaqiriladigan callback
  final ValueChanged<String>? onChanged;
  
  /// Placeholder text
  final String hintText;
  
  /// Qidiruvni tozalash funksiyasi
  final VoidCallback? onClear;

  const SearchBarWidget({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText = 'Search...',
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  onClear?.call();
                  onChanged?.call('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: onChanged,
    );
  }
}

