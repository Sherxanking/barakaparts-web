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
import '../../data/models/order_model.dart' as data; // Import the data model
import '../../data/services/product_service.dart';
import '../../data/services/part_service.dart';
import '../../data/services/order_service.dart'; // OrderService import
import '../../core/di/service_locator.dart';
import '../../core/services/auth_state_service.dart'; // AuthStateService import
import '../widgets/status_badge_widget.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/order_parts_list_widget.dart';
import '../../l10n/app_localizations.dart';

class OrderItemWidget extends StatefulWidget {
  final domain.Order order;
  final data.Order? dataOrder; // Optional data model for extended fields
  final Department? department;
  final VoidCallback? onComplete; // Nullable - permission-based
  final VoidCallback? onEdit; // Nullable - for pending orders
  final VoidCallback? onDelete; // Nullable - permission-based
  final bool isCompleting; // OPTIMIZATION: Loading state
  final VoidCallback? onCourierAssign;
  final bool isCourierMode; // Flag to enable courier assignment mode

  const OrderItemWidget({
    super.key,
    required this.order,
    this.dataOrder,
    this.department,
    this.onComplete,
    this.onEdit,
    this.onDelete,
    this.isCompleting = false, // Default: not loading
    this.onCourierAssign,
    this.isCourierMode = false,
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
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(
                color: _getStatusColor(widget.order.status),
                width: 10,
              ),
            ),
          ),
          child: InkWell(
            onTap: () {
              // Order details (keyinchalik qo'shilishi mumkin)
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Product name va Visual Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.order.productName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: Color(0xFF1A1C1E),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Visual Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: (widget.order.quantity > 0) ? (widget.order.completedQuantity / widget.order.quantity) : 0,
                                backgroundColor: Colors.grey.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getPercentageColor((widget.order.quantity > 0) ? (widget.order.completedQuantity / widget.order.quantity) * 100 : 0),
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadgeWidget(status: widget.order.status),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.order.completedQuantity} / ${widget.order.quantity}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (widget.isCourierMode)
                            IconButton(
                              onPressed: widget.onCourierAssign,
                              icon: const Icon(Icons.delivery_dining, color: Color(0xFFF2994A)),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFF2994A).withOpacity(0.1),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Feasibility Section (NEW)
                  if (widget.order.status == 'pending' || widget.order.status == 'in_progress')
                    _buildFeasibilityInfo(),
                  
                  const SizedBox(height: 12),
                  
                  // Metadata Section - Clean Grid
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 4,
                          children: [
                            if (widget.department != null)
                              _buildInfoRow(
                                Icons.business_outlined,
                                widget.department!.name,
                                Colors.grey.shade700,
                              ),
                            _buildInfoRow(
                              Icons.calendar_today_outlined,
                              widget.order.createdAt.toString().substring(5, 16),
                              Colors.grey.shade600,
                            ),
                            _buildInfoRow(
                              Icons.person_outline,
                              (widget.order.soldTo?.isNotEmpty == true) ? widget.order.soldTo! : 'Noma\'lum',
                              Colors.purple.shade600,
                              label: 'Mijoz:',
                            ),
                            if (widget.order.workerId != null && widget.order.workerId!.isNotEmpty)
                              FutureBuilder<String?>(
                                future: _getWorkerName(widget.order.workerId!),
                                builder: (context, snapshot) {
                                  final workerName = snapshot.data ?? '...';
                                  return _buildInfoRow(
                                    Icons.engineering_outlined,
                                    workerName,
                                    Colors.blue.shade800,
                                    isBold: true,
                                  );
                                },
                              ),
                          ],
                        ),
                        if (widget.order.completedAt != null || widget.order.durationHours != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(height: 1),
                          ),
                          Row(
                            children: [
                              if (widget.order.completedAt != null)
                                Expanded(
                                  child: _buildInfoRow(
                                    Icons.task_alt_outlined,
                                    widget.order.completedAt!.toString().substring(5, 16),
                                    Colors.green.shade700,
                                  ),
                                ),
                              if (widget.order.durationHours != null)
                                Expanded(
                                  child: _buildInfoRow(
                                    Icons.hourglass_bottom_outlined,
                                    '${widget.order.durationHours!.toStringAsFixed(1)}s',
                                    Colors.orange.shade800,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
                      // Show taken items if any
                      if (widget.dataOrder?.takenItems != null && widget.dataOrder!.takenItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Divider(color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text(
                          'Taken Items',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.dataOrder!.takenItems.map((takenItem) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Colors.green[50],
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Quantity: ${takenItem.quantity}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  ),
                                  if (takenItem.notes != null && takenItem.notes!.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        'Notes: ${takenItem.notes}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[800],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ],
                  
                  const SizedBox(height: 12),
                  
                  // Action buttons Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Primary Actions
                      if (widget.order.status == 'pending' && widget.onComplete != null && _hasStartPermission())
                        _buildActionButton(
                          onPressed: () => _showStartOrderDialog(context),
                          icon: Icons.play_arrow,
                          label: 'Start',
                          color: Colors.orange.shade700,
                        ),
                      
                      if ((widget.order.status == 'in_progress' || widget.order.status == 'partially_completed') && 
                          widget.onComplete != null && _hasCompletePermission()) ...[
                        _buildActionButton(
                          onPressed: () => _showPartialCompleteDialog(context),
                          icon: Icons.check_circle_outline,
                          label: 'Partial',
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          onPressed: widget.isCompleting ? null : widget.onComplete!,
                          icon: Icons.check_circle,
                          label: AppLocalizations.of(context)?.translate('complete') ?? 'Finish',
                          color: Colors.green.shade700,
                          isLoading: widget.isCompleting,
                        ),
                        if (widget.order.quantity > 1 && widget.order.completedQuantity < widget.order.quantity) ...[
                          const SizedBox(width: 8),
                          _buildActionButton(
                            onPressed: () => _completeOneItem(context),
                            icon: Icons.add,
                            label: '+1',
                            color: Colors.blue.shade700,
                          ),
                        ],
                      ],

                      const Spacer(),

                      // Secondary Actions (Popup Menu)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'edit' && widget.onEdit != null) widget.onEdit!();
                          if (value == 'delete' && widget.onDelete != null) widget.onDelete!();
                        },
                        itemBuilder: (context) => [
                          if (['pending', 'in_progress', 'partially_completed'].contains(widget.order.status) && 
                            widget.onEdit != null && _hasEditPermission())
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                          if (widget.onDelete != null)
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(_isBoss() ? 'Permanent Delete' : 'Delete'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Worker name olish
  Future<String?> _getWorkerName(String workerId) async {
    try {
      // UserRepository orqali worker name olish
      final userRepository = ServiceLocator.instance.userRepository;
      final result = await userRepository.getUserById(workerId);
      
      return result.fold(
        (failure) {
          debugPrint('❌ Failed to get worker name: ${failure.message}');
          return 'Unknown Worker';
        },
        (user) {
          return user?.name ?? 'Unknown Worker';
        },
      );
    } catch (e) {
      debugPrint('❌ Error getting worker name: $e');
      return 'Unknown Worker';
    }
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

  /// Get border color based on order status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF2C94C); // Warning Yellow
      case 'in_progress':
        return const Color(0xFF2F80ED); // Info Blue
      case 'partially_completed':
        return const Color(0xFF9B51E0); // Purple
      case 'completed':
        return const Color(0xFF27AE60); // Success Green
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFEB5757); // Danger Red
      default:
        return const Color(0xFFBDBDBD); // Grey
    }
  }

  /// Get color based on completion percentage
  Color _getPercentageColor(double percentage) {
    if (percentage >= 100) {
      return Colors.green[700]!;
    } else if (percentage >= 50) {
      return Colors.orange[700]!;
    } else {
      return Colors.grey[600]!;
    }
  }

  /// Check if current user has edit permission
  bool _hasEditPermission() {
    final currentUser = AuthStateService().currentUser;
    // Faqat Boss va Manager edit qila oladi
    return currentUser != null && (currentUser.isManager || currentUser.isBoss);
  }

  /// Check if current user has start permission (assign worker)
  bool _hasStartPermission() {
    final currentUser = AuthStateService().currentUser;
    return currentUser != null && (currentUser.isManager || currentUser.isBoss);
  }

  /// Check if current user has complete permission
  bool _hasCompletePermission() {
    final currentUser = AuthStateService().currentUser;
    return currentUser != null && (currentUser.isManager || currentUser.isBoss);
  }

  /// Check if current user is boss
  bool _isBoss() {
    final currentUser = AuthStateService().currentUser;
    return currentUser != null && currentUser.isBoss;
  }

  /// Show start order dialog (assign worker)
  void _showStartOrderDialog(BuildContext context) {
    // This would open a dialog to assign worker and start the order
    // Implementation depends on your needs
    debugPrint('Start order dialog would be shown here');
  }

  /// Show partial completion dialog
  void _showPartialCompleteDialog(BuildContext context) {
    // This would open a dialog to enter how many items to complete
    // Implementation depends on your needs
    debugPrint('Partial complete dialog would be shown here');
  }

  /// Complete one item of the order
  Future<void> _completeOneItem(BuildContext context) async {
    final orderService = OrderService();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete One Item'),
        content: Text(
          'Are you sure you want to complete 1 item of ${widget.order.productName}?\n'
          'Completed: ${widget.order.completedQuantity + 1}/${widget.order.quantity}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      bool success;
      if (widget.order.status == 'partially_completed' || widget.order.completedQuantity > 0) {
        // Add to existing partial completion
        success = await orderService.addPartialCompletion(widget.order.id, 1);
      } else {
        // Start with 1 completed
        success = await orderService.partiallyCompleteOrder(widget.order.id, 1);
      }
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('1 item completed for ${widget.order.productName}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to complete item'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Buttonni yaratish uchun helper
  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color, width: 1),
        ),
      ),
      icon: isLoading 
          ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
          : Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  /// Helper to build a consistent info row with icon and text
  Widget _buildInfoRow(IconData icon, String text, Color color, {String? label, bool isBold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        if (label != null) ...[
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 2),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Build Feasibility Info Widget
  Widget _buildFeasibilityInfo() {
    final product = _getProduct();
    if (product == null) return const SizedBox.shrink();

    final partService = PartService();
    int minPossible = 999999;
    Map<String, int> shortages = {};

    product.parts.forEach((partId, reqQty) {
      final part = partService.getPartById(partId);
      final currentStock = part?.quantity ?? 0;
      
      final possibleForThisPart = currentStock ~/ reqQty;
      if (possibleForThisPart < minPossible) {
        minPossible = possibleForThisPart;
      }

      final totalNeeded = reqQty * widget.order.quantity;
      if (currentStock < totalNeeded) {
        shortages[partId] = totalNeeded - currentStock;
      }
    });

    if (minPossible > widget.order.quantity) minPossible = widget.order.quantity;

    final bool isFullyPossible = minPossible >= widget.order.quantity;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFullyPossible ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFullyPossible ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFullyPossible ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 20,
                color: isFullyPossible ? Colors.green.shade700 : Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFullyPossible 
                      ? 'Ishlab chiqarishga tayyor: ${widget.order.quantity} ta'
                      : 'Hozirda faqat $minPossible ta uchun qism yetarli',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isFullyPossible ? Colors.green.shade900 : Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          if (shortages.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),
            Text(
              'Yetishmayotgan qismlar:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: shortages.entries.map((e) {
                final part = partService.getPartById(e.key);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Text(
                    '${part?.name ?? e.key}: -${e.value}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

