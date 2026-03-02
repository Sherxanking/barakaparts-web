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
    final statusColor = _getStatusColor(widget.order.status);
    // FIX: Const constructor ishlatish - rebuild optimizatsiyasi
    return AnimatedListItem(
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(
                color: statusColor,
                width: 6,
              ),
            ),
          ),
          child: InkWell(
            onTap: () {
              // Order details
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Mahsulot nomi va Miqdor (Fokus)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.order.productName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1C1E),
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '× ${widget.order.quantity}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadgeWidget(status: widget.order.status, compact: true),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // Row 2: Metadata Breadcrumbs (Ixcham)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (widget.department != null) ...[
                              _buildBreadcrumb(Icons.business_outlined, widget.department!.name),
                              _buildSeparator(),
                            ],
                            _buildBreadcrumb(
                              Icons.person_outline, 
                              (widget.order.soldTo?.isNotEmpty == true) ? widget.order.soldTo! : 'Noma\'lum'
                            ),
                            _buildSeparator(),
                            _buildBreadcrumb(
                              Icons.calendar_today_outlined, 
                              widget.order.createdAt.toString().substring(5, 16)
                            ),
                            // Worker if exists
                            if (widget.order.workerId != null && widget.order.workerId!.isNotEmpty) ...[
                               _buildSeparator(),
                               FutureBuilder<String?>(
                                 future: _getWorkerName(widget.order.workerId!),
                                 builder: (context, snapshot) => _buildBreadcrumb(
                                   Icons.engineering_outlined, 
                                   snapshot.data ?? '...'
                                 ),
                               ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Row 3: Feasibility (SubtleBadge)
                      if (widget.order.status == 'pending' || widget.order.status == 'in_progress')
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _buildCompactFeasibility(),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Row 4: Actions (Tozalangan)
                      Row(
                        children: [
                          // Parts toggle (Icon bilan)
                          IconButton(
                            onPressed: () => setState(() => _showParts = !_showParts),
                            icon: Icon(
                              _showParts ? Icons.build_circle : Icons.build_circle_outlined,
                              color: _showParts ? Colors.blue.shade700 : Colors.grey.shade400,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Qismlar',
                          ),
                          const Spacer(),
                          
                          // Primary Actions
                          if (widget.order.status == 'completed') 
                            _buildActionButton(
                              onPressed: () => _showProductHistoryDialog(context),
                              icon: Icons.bar_chart_rounded,
                              label: 'Hisobot',
                              color: Colors.purple.shade700,
                              isCompact: true,
                            ),
                          
                          if ((widget.order.status == 'pending' || widget.order.status == 'in_progress' || widget.order.status == 'partially_completed') && 
                              widget.onComplete != null && _hasCompletePermission()) ...[
                            _buildActionButton(
                              onPressed: widget.isCompleting ? null : () => _handleFinish(context),
                              icon: Icons.check_circle_rounded,
                              label: 'Tugatish',
                              color: Colors.green.shade700,
                              isLoading: widget.isCompleting,
                              isCompact: true,
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(
                              onPressed: () => _completeOneItem(context),
                              icon: Icons.add_rounded,
                              label: '+1',
                              color: Colors.blue.shade700,
                              isCompact: true,
                            ),
                          ],

                          // Extra menu
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz_rounded),
                            onSelected: (value) {
                              if (value == 'edit' && widget.onEdit != null) widget.onEdit!();
                              if (value == 'delete' && widget.onDelete != null) widget.onDelete!();
                              if (value == 'partial') _showPartialCompleteDialog(context);
                            },
                            itemBuilder: (context) => [
                              if (['pending', 'in_progress', 'partially_completed'].contains(widget.order.status))
                                const PopupMenuItem(
                                  value: 'partial',
                                  child: Row(children: [Icon(Icons.history, size: 20), SizedBox(width: 8), Text('Partial')]),
                                ),
                              if (['pending', 'in_progress', 'partially_completed'].contains(widget.order.status) && 
                                  widget.onEdit != null && _hasEditPermission())
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [Icon(Icons.edit_outlined, size: 20, color: Colors.blue), SizedBox(width: 8), Text('Edit')]),
                                ),
                              if (widget.onDelete != null)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete')]),
                                ),
                            ],
                          ),
                        ],
                      ),
                      
                      // Parts Section (Expandable)
                      if (_showParts) ...[
                        const Divider(height: 24),
                        _buildPartsList(context),
                      ],
                    ],
                  ),
                ),
                
                // Row 5: Integrated Slim Progress Bar (Bottom)
                if (widget.order.quantity > 0)
                  SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      value: widget.order.completedQuantity / widget.order.quantity,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getPercentageColor((widget.order.completedQuantity / widget.order.quantity) * 100),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Breadcrumb helper
  Widget _buildBreadcrumb(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  /// Separator dot helper
  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.circle, size: 3, color: Colors.grey.shade300),
    );
  }

  /// Compact Feasibility Badge
  Widget _buildCompactFeasibility() {
    final product = _getProduct();
    if (product == null) return const SizedBox.shrink();

    final partService = PartService();
    int minPossible = 999999;

    product.parts.forEach((partId, reqQty) {
      final part = partService.getPartById(partId);
      final currentStock = part?.quantity ?? 0;
      final possibleForThisPart = currentStock ~/ reqQty;
      if (possibleForThisPart < minPossible) minPossible = possibleForThisPart;
    });

    if (minPossible > widget.order.quantity) minPossible = widget.order.quantity;
    final bool isReady = minPossible >= widget.order.quantity;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isReady ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isReady ? Colors.green.shade100 : Colors.orange.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isReady ? Icons.check_circle_rounded : Icons.warning_rounded,
            size: 14,
            color: isReady ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            isReady ? 'Terishga tayyor' : 'Qismlar kam: $minPossible ta tayyor',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isReady ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ],
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
    // Boss, Manager yoki har qanday ruxsati bor xodim boshlashi mumkin
    return currentUser != null && (currentUser.canManageOrders || currentUser.isManager || currentUser.isBoss);
  }

  /// Check if current user has complete permission
  bool _hasCompletePermission() {
    final currentUser = AuthStateService().currentUser;
    if (currentUser == null) return false;

    // Boss va Manager hamma narsani tugata oladi
    if (currentUser.isBoss || currentUser.isManager) return true;

    // Ishchi faqat o'ziga biriktirilgan orderni tugata oladi
    if (widget.order.workerId != null && widget.order.workerId == currentUser.id) {
      return true;
    }

    // Worker role ruxsati bo'lsa ham
    return currentUser.canCompleteOrders;
  }


  /// Show start order dialog (assign worker)
  Future<void> _showStartOrderDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final orderService = OrderService();
    final workers = await orderService.getWorkers();
    
    if (!context.mounted) return;

    final selectedWorkerId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.translate('selectWorker') ?? 'Ishchini tanlang'),
        content: SizedBox(
          width: double.maxFinite,
          child: workers.isEmpty 
            ? Text(l10n?.translate('noWorkersFound') ?? 'Ishchilar topilmadi')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: workers.length,
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(worker.name),
                    subtitle: Text(worker.role),
                    onTap: () => Navigator.pop(context, worker.id),
                  );
                },
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n?.translate('cancel') ?? 'Bekor qilish'),
          ),
        ],
      ),
    );

    if (selectedWorkerId != null && context.mounted) {
      final success = await orderService.startOrderWithTimeTracking(widget.order.id, selectedWorkerId);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.translate('orderStarted') ?? 'Buyurtma boshlandi'), 
              backgroundColor: Colors.green
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.translate('errorOccurred') ?? 'Xatolik yuz berdi'), 
              backgroundColor: Colors.red
            ),
          );
        }
      }
    }
  }

  /// Handle Finish order with shortage check
  Future<void> _handleFinish(BuildContext context) async {
    final orderService = OrderService();
    final product = _getProduct();
    if (product == null) return;

    // Check availability
    final partService = PartService();
    bool hasShortage = false;
    final shortageList = <String>[];

    product.parts.forEach((partId, reqQty) {
      final part = partService.getPartById(partId);
      final totalNeeded = reqQty * widget.order.quantity;
      if (part == null || part.quantity < totalNeeded) {
        hasShortage = true;
        shortageList.add(part?.name ?? 'Noma\'lum qism ($partId)');
      }
    });

    if (hasShortage) {
      final l10n = AppLocalizations.of(context);
      final bool? force = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n?.translate('partsShortageTitle') ?? 'Qismlar yetishmayapti!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n?.translate('partsShortageContent') ?? 'Quyidagi qismlar omborda yetarli emas:'),
              const SizedBox(height: 8),
              ...shortageList.map((p) => Text('• $p', style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 16),
              Text(l10n?.translate('forceFinishConfirm') ?? 'Shunday bo\'lsa ham tugatilsinmi? (Qismlar ombordan ayirilmaydi)'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n?.translate('cancel') ?? 'Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(l10n?.translate('forceFinish') ?? 'Majburiy tugatish'),
            ),
          ],
        ),
      );

      if (force == true && context.mounted) {
        final dataOrder = orderService.getOrderById(widget.order.id);
        if (dataOrder != null) {
          final success = await orderService.completeOrder(dataOrder, isForce: true);
          if (context.mounted && success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n?.translate('orderForceFinished') ?? 'Buyurtma majburiy tugatildi'), 
                backgroundColor: Colors.orange
              ),
            );
          }
        }
      }
    } else {
      // No shortage, just complete normally
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    }
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

  /// Show simple report dialog
  void _showProductHistoryDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    int today = 0;
    int week = 0;
    int month = 0;

    try {
      final repository = ServiceLocator.instance.orderRepository;
      final result = await repository.getAllOrders();
      result.fold(
        (_) {},
        (orders) {
          final now = DateTime.now();
          final startToday = DateTime(now.year, now.month, now.day);
          final startWeek = startToday.subtract(Duration(days: startToday.weekday - 1));
          final startMonth = DateTime(now.year, now.month, 1);

          for (final o in orders) {
            if (o.status == 'completed' && o.productName == widget.order.productName) {
              final date = o.updatedAt ?? o.createdAt;
              final dOnly = DateTime(date.year, date.month, date.day);
              if (!dOnly.isBefore(startMonth)) {
                month += o.quantity;
                if (!dOnly.isBefore(startWeek)) {
                  week += o.quantity;
                  if (!dOnly.isBefore(startToday)) {
                    today += o.quantity;
                  }
                }
              }
            }
          }
        },
      );
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.pop(context); // close loading

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${widget.order.productName}\nhisoboti', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.today, color: Colors.blue),
                title: const Text('Bugun tayyorlandi'),
                trailing: Text('$today ta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range, color: Colors.orange),
                title: const Text('Hafta davomida'),
                trailing: Text('$week ta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: Colors.green),
                title: const Text('Shu oyda d/m'),
                trailing: Text('$month ta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yopish'),
            ),
          ],
        );
      },
    );
  }

  /// Buttonni yaratish uchun helper
  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isLoading = false,
    bool isCompact = false,
  }) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16, 
          vertical: isCompact ? 6 : 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color, width: 1),
        ),
        minimumSize: isCompact ? const Size(0, 32) : null,
      ),
      icon: isLoading 
          ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
          : Icon(icon, size: isCompact ? 16 : 18),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold, 
          fontSize: isCompact ? 12 : 13,
        ),
      ),
    );
  }

}

