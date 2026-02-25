import 'package:flutter/material.dart';
import '../../data/models/product_model.dart';
import '../../l10n/app_localizations.dart';

class ProductConfirmationDialog extends StatelessWidget {
  final Product? existingProduct;
  final String productName;
  final String departmentName;
  final Map<String, int> selectedParts;

  const ProductConfirmationDialog({
    super.key,
    this.existingProduct,
    required this.productName,
    required this.departmentName,
    required this.selectedParts,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = existingProduct != null;

    return AlertDialog(
      title: Text(
        isEditing
            ? (l10n?.translate('confirmUpdate') ?? 'Confirm Update')
            : (l10n?.translate('confirmCreate') ?? 'Confirm Creation'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n?.translate('productName') ?? 'Product Name'}: $productName',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n?.translate('department') ?? 'Department'}: $departmentName',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n?.translate('partsCount') ?? 'Parts Count'}: ${selectedParts.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (selectedParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n?.translate('selectedParts') ?? 'Selected Parts:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...selectedParts.entries
                .take(5)
                .map(
                  (entry) => Text(
                    '- ${entry.value} x [Part ID: ${entry.key.substring(0, 8)}...]',
                  ),
                ),
            if (selectedParts.length > 5)
              Text(
                '+ ${selectedParts.length - 5} more',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            isEditing
                ? (l10n?.save ?? 'Save')
                : (l10n?.translate('create') ?? 'Create'),
          ),
        ),
      ],
    );
  }
}
