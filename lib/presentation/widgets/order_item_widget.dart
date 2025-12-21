/// OrderItemWidget - Buyurtma ro'yxat elementi widget'i
/// 
/// Bu widget buyurtma ro'yxatidagi har bir elementni ko'rsatadi.
/// Alohida widget sifatida ajratilgan - performance optimizatsiyasi uchun.
/// 
/// FIX: ListView ichidagi rebuild muammosini hal qilish uchun
/// alohida widget sifatida yaratildi.
import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';
import '../../data/models/department_model.dart';
import '../../data/models/product_model.dart';
import '../../data/services/product_service.dart';
import '../../data/services/part_service.dart';
import '../widgets/status_badge_widget.dart';
import '../widgets/animated_list_item.dart';
import '../../l10n/app_localizations.dart';

class OrderItemWidget extends StatelessWidget {
  final Order order;
  final Department? department;
  final VoidCallback? onComplete; // Nullable - permission-based
  final VoidCallback? onDelete; // Nullable - permission-based
  final bool isCompleting; // OPTIMIZATION: Loading state

  const OrderItemWidget({
    super.key,
    required this.order,
    this.department,
    this.onComplete,
    this.onDelete,
    this.isCompleting = false, // Default: not loading
  });

  /// Product'dan parts olish
  Product? _getProduct() {
    try {
      final productService = ProductService();
      return productService.getAllProducts().firstWhere(
        (p) => p.name == order.productName,
        orElse: () => throw StateError('Product not found'),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Const constructor ishlatish - rebuild optimizatsiyasi
    return AnimatedListItem(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        child: InkWell(
          onTap: () {
            // Order details (keyinchalik qo'shilishi mumkin)
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Product name va Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        order.productName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadgeWidget(status: order.status),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Department info
                if (department != null)
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        department!.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                
                // Quantity
                Row(
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${AppLocalizations.of(context)?.translate('quantity') ?? 'Quantity'}: ${order.quantity}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Created date
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${AppLocalizations.of(context)?.translate('created') ?? 'Created'}: ${order.createdAt.toString().substring(0, 16)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                // FIX: Completed order bo'lsa, parts ko'rsatish
                if (order.status == 'completed') ...[
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.build,
                        size: 16,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)?.translate('partsUsed') ?? 'Parts Used',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildPartsList(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Action buttons (only show if permissions allow)
                if ((order.status == 'pending' && onComplete != null) || onDelete != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Complete button (only for pending orders and if permission granted)
                      if (order.status == 'pending' && onComplete != null)
                        TextButton.icon(
                          onPressed: isCompleting ? null : onComplete, // Disable while loading
                          icon: isCompleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                  ),
                                )
                              : const Icon(Icons.check_circle, size: 18),
                          label: Text(AppLocalizations.of(context)?.translate('complete') ?? 'Complete'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                          ),
                        ),
                      if (order.status == 'pending' && onComplete != null && onDelete != null)
                        const SizedBox(width: 8),
                      // Delete button (only if permission granted)
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: onDelete,
                          tooltip: AppLocalizations.of(context)?.translate('deleteOrder') ?? 'Delete Order',
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Parts list'ni ko'rsatish
  Widget _buildPartsList(BuildContext context) {
    final product = _getProduct();
    if (product == null || product.parts.isEmpty) {
      return Text(
        AppLocalizations.of(context)?.translate('noParts') ?? 'No parts',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final partService = PartService();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: product.parts.entries.map((entry) {
        final partId = entry.key;
        final qtyPerProduct = entry.value;
        final totalQty = qtyPerProduct * order.quantity;
        final part = partService.getPartById(partId);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 6,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${part?.name ?? partId}: $qtyPerProduct × ${order.quantity} = $totalQty',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

