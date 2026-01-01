/// OrderItemWidget - Buyurtma ro'yxat elementi widget'i
/// 
/// Bu widget buyurtma ro'yxatidagi har bir elementni ko'rsatadi.
/// Alohida widget sifatida ajratilgan - performance optimizatsiyasi uchun.
/// 
/// FIX: ListView ichidagi rebuild muammosini hal qilish uchun
/// alohida widget sifatida yaratildi.
import 'package:flutter/material.dart';
import '../../domain/entities/order.dart' as domain;
import '../../data/models/department_model.dart';
import '../../data/models/product_model.dart';
import '../../data/services/product_service.dart';
import '../../data/services/part_service.dart';
import '../widgets/status_badge_widget.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/order_parts_list_widget.dart';
import '../../l10n/app_localizations.dart';

class OrderItemWidget extends StatefulWidget {
  final domain.Order order;
  final Department? department;
  final VoidCallback? onComplete; // Nullable - permission-based
  final VoidCallback? onEdit; // Nullable - for pending orders
  final VoidCallback? onDelete; // Nullable - permission-based
  final bool isCompleting; // OPTIMIZATION: Loading state

  const OrderItemWidget({
    super.key,
    required this.order,
    this.department,
    this.onComplete,
    this.onEdit,
    this.onDelete,
    this.isCompleting = false, // Default: not loading
  });

  @override
  State<OrderItemWidget> createState() => _OrderItemWidgetState();
}

class _OrderItemWidgetState extends State<OrderItemWidget> {
  bool _showParts = false; // Parts ko'rsatilishi/yashirilishi

  /// Product'dan parts olish
  Product? _getProduct() {
    try {
      final productService = ProductService();
      return productService.getAllProducts().firstWhere(
        (p) => p.name == widget.order.productName,
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
                        widget.order.productName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadgeWidget(status: widget.order.status),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Department info
                if (widget.department != null)
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.department!.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                
                // Quantity va Sold To bir qatorda
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Quantity
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${AppLocalizations.of(context)?.translate('quantity') ?? 'Quantity'}: ${widget.order.quantity}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    // Sold To (chiroyli badge formatida - har doim ko'rsatiladi)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (widget.order.soldTo != null && widget.order.soldTo!.isNotEmpty)
                            ? Colors.purple.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (widget.order.soldTo != null && widget.order.soldTo!.isNotEmpty)
                              ? Colors.purple.shade200
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (widget.order.soldTo != null && widget.order.soldTo!.isNotEmpty)
                                ? Icons.person
                                : Icons.person_outline,
                            size: 16,
                            color: (widget.order.soldTo != null && widget.order.soldTo!.isNotEmpty)
                                ? Colors.purple.shade700
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${AppLocalizations.of(context)?.translate('soldTo') ?? 'Kimga sotilgan'}: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: (widget.order.soldTo != null && widget.order.soldTo!.isNotEmpty)
                                  ? Colors.purple.shade800
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            (widget.order.soldTo != null && widget.order.soldTo!.isNotEmpty)
                                ? widget.order.soldTo!
                                : 'Ko\'rsatilmagan',
                            style: TextStyle(
                              fontSize: 13,
                              color: (widget.order.soldTo != null && widget.order.soldTo!.isNotEmpty)
                                  ? Colors.purple.shade900
                                  : Colors.grey.shade600,
                              fontWeight: (widget.order.soldTo != null && widget.order.soldTo!.isNotEmpty)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontStyle: (widget.order.soldTo != null && widget.order.soldTo!.isNotEmpty)
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ],
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
                      '${AppLocalizations.of(context)?.translate('created') ?? 'Created'}: ${widget.order.createdAt.toString().substring(0, 16)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                // FIX: Barcha orderlar uchun parts ko'rsatish (ixcham - icon bilan yashirib turish)
                // Completed va Pending orderlar uchun ham
                ...[
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showParts = !_showParts;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          _showParts ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: widget.order.status == 'completed' ? Colors.green[700] : Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.build,
                          size: 18,
                          color: widget.order.status == 'completed' ? Colors.green[700] : Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.order.status == 'completed' 
                              ? (AppLocalizations.of(context)?.translate('partsUsed') ?? 'Parts Used')
                              : (AppLocalizations.of(context)?.translate('partsRequired') ?? 'Parts Required'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: widget.order.status == 'completed' ? Colors.green[700] : Colors.blue[700],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _showParts ? 'Yig\'ish' : 'Ko\'rsatish',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.order.status == 'completed' ? Colors.green[600] : Colors.blue[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showParts) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        debugPrint('✅ Order ${widget.order.id} - _showParts = true, _buildPartsList chaqirilmoqda');
                        return _buildPartsList(context);
                      },
                    ),
                  ],
                ],
                
                const SizedBox(height: 12),
                
                // Action buttons (only show if permissions allow)
                if ((widget.order.status == 'pending' && (widget.onComplete != null || widget.onEdit != null)) || widget.onDelete != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Edit button (only for pending orders)
                      if (widget.order.status == 'pending' && widget.onEdit != null)
                        TextButton.icon(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit, size: 18),
                          label: Text(AppLocalizations.of(context)?.translate('edit') ?? 'Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                        ),
                      if (widget.order.status == 'pending' && widget.onEdit != null && widget.onComplete != null)
                        const SizedBox(width: 8),
                      // Complete button (only for pending orders and if permission granted)
                      if (widget.order.status == 'pending' && widget.onComplete != null)
                        TextButton.icon(
                          onPressed: widget.isCompleting ? null : widget.onComplete, // Disable while loading
                          icon: widget.isCompleting
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
                      if ((widget.order.status == 'pending' && (widget.onComplete != null || widget.onEdit != null)) && widget.onDelete != null)
                        const SizedBox(width: 8),
                      // Delete button (only if permission granted)
                      if (widget.onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: widget.onDelete,
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

  /// Parts list'ni ko'rsatish (chiroyli badge'lar bilan)
  Widget _buildPartsList(BuildContext context) {
    // FIX: Order'da saqlangan partsRequired dan foydalanish (snapshot)
    // Agar partsRequired null bo'lsa, product.parts dan fallback
    final partsToShow = widget.order.partsRequired;
    
    // DEBUG: partsRequired ni tekshirish
    debugPrint('🔍 Order ${widget.order.id} (${widget.order.productName}) - partsRequired: ${partsToShow?.toString() ?? "null"}');
    debugPrint('🔍 Order ${widget.order.id} - partsRequired isEmpty: ${partsToShow?.isEmpty ?? true}');
    debugPrint('🔍 Order ${widget.order.id} - partsRequired length: ${partsToShow?.length ?? 0}');
    
    if (partsToShow == null || partsToShow.isEmpty) {
      debugPrint('⚠️ Order ${widget.order.id} - partsRequired null yoki bo\'sh, product.parts dan fallback');
      // Fallback: Product'dan parts olish
      final product = _getProduct();
      if (product == null || product.parts.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            AppLocalizations.of(context)?.translate('noParts') ?? 'No parts',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
      
      // Fallback: Product parts ishlatish
      final partService = PartService();
      return OrderPartsListWidget(
        parts: product.parts,
        orderQuantity: widget.order.quantity,
        partService: partService,
      );
    }

    // Order'da saqlangan partsRequired ishlatish
    final partService = PartService();
    
    return OrderPartsListWidget(
      parts: partsToShow,
      orderQuantity: widget.order.quantity,
      partService: partService,
    );
  }
}

