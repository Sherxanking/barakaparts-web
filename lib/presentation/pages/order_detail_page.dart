import 'package:flutter/material.dart';
import '../../data/models/order_model.dart' as data;
import '../../data/services/department_service.dart';
import '../../data/services/order_service.dart';
import '../../data/services/product_service.dart';
import '../../data/services/part_service.dart'; 
import '../../core/services/auth_state_service.dart';
import '../widgets/order_parts_list_widget.dart';
import '../../l10n/app_localizations.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final OrderService _orderService = OrderService();
  final DepartmentService _departmentService = DepartmentService();
  final PartService _partService = PartService();
  final ProductService _productService = ProductService();

  bool _isRefreshing = false;

  void _refresh() {
    if (mounted) {
      setState(() {
        _isRefreshing = !_isRefreshing;
      });
    }
  }

  bool _hasStartPermission() {
    final currentUser = AuthStateService().currentUser;
    return currentUser != null && (currentUser.canManageOrders || currentUser.isManager || currentUser.isBoss);
  }

  bool _hasCompletePermission(data.Order order) {
    final currentUser = AuthStateService().currentUser;
    if (currentUser == null) return false;
    if (currentUser.isBoss || currentUser.isManager) return true;
    if (order.workerId != null && order.workerId == currentUser.id) return true;
    return currentUser.canCompleteOrders;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = _orderService.getOrderById(widget.orderId);
    
    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n?.translate('orderNotFound') ?? 'Order Not Found')),
        body: Center(child: Text(l10n?.translate('orderNotFound') ?? 'Order not found')),
      );
    }

    final department = _departmentService.getDepartmentById(order.departmentId);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.translate('orderDetails') ?? 'Order Details'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order Info Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.translate('orderInfo') ?? 'Order Information',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.inventory, l10n?.translate('productLabel') ?? 'Product', order.productName),
                    if (department != null)
                      _buildInfoRow(Icons.business, l10n?.translate('departmentLabel') ?? 'Department', department.name),
                    _buildInfoRow(Icons.numbers, l10n?.translate('quantityLabel') ?? 'Quantity', '${order.quantity}'),
                    _buildInfoRow(Icons.label, l10n?.translate('statusLabel') ?? 'Status', order.status.toUpperCase()),
                    _buildInfoRow(Icons.calendar_today, l10n?.translate('createdLabel') ?? 'Created', order.createdAt.toString().substring(0, 16)),
                    if (order.startedAt != null)
                      _buildInfoRow(Icons.play_arrow, l10n?.translate('startedLabel') ?? 'Started', order.startedAt!.toString().substring(0, 16)),
                    if (order.completedAt != null)
                      _buildInfoRow(Icons.check_circle_outline, l10n?.translate('completedLabel') ?? 'Completed', order.completedAt!.toString().substring(0, 16)),
                    if (order.durationHours != null)
                      _buildInfoRow(Icons.timer, l10n?.translate('durationLabel') ?? 'Duration', '${order.durationHours!.toStringAsFixed(1)} hours'),
                    if (order.soldTo != null && order.soldTo!.isNotEmpty)
                      _buildInfoRow(Icons.person, l10n?.translate('soldToLabel') ?? 'Sold To', order.soldTo!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Parts Required Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.translate('partsRequired') ?? 'Parts Required',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OrderPartsListWidget(
                      parts: order.partsRequired != null 
                          ? Map<String, int>.from(order.partsRequired as Map)
                          : {},
                      orderQuantity: order.quantity,
                      partService: _partService,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            if (order.status == 'pending' && _hasStartPermission())
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startOrder(context, order),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n?.translate('start') ?? 'Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if ((order.status == 'in_progress' || order.status == 'partially_completed') && _hasCompletePermission(order)) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _finishOrder(context, order),
                  icon: const Icon(Icons.check_circle),
                  label: Text(l10n?.translate('finish') ?? 'Finish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _incrementOrder(context, order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
                child: const Icon(Icons.add),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startOrder(BuildContext context, data.Order order) async {
    final l10n = AppLocalizations.of(context);
    final workers = await _orderService.getWorkers();
    if (!mounted) return;

    if (workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.translate('noWorkersFound') ?? 'Ishchilar topilmadi'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedWorkerId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.translate('selectWorker') ?? 'Ishchini tanlang'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: workers.length,
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.person),
              title: Text(workers[index].name),
              subtitle: Text(workers[index].role),
              onTap: () => Navigator.pop(context, workers[index].id),
            ),
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

    if (selectedWorkerId != null && mounted) {
      final success = await _orderService.startOrderWithTimeTracking(order.id, selectedWorkerId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.translate('orderStarted') ?? 'Buyurtma boshlandi'),
            backgroundColor: Colors.green,
          ),
        );
        _refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.translate('errorOccurred') ?? 'Xatolik yuz berdi. Logni tekshiring.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _finishOrder(BuildContext context, data.Order order) async {
    final l10n = AppLocalizations.of(context);
    final product = _productService.getProductByName(order.productName);
    if (product == null) {
      // Agar mahsulot topilmasa, shunchaki tugatishga harakat qilamiz
      final success = await _orderService.completeOrder(order);
      if (success) _refresh();
      return;
    }

    bool hasShortage = false;
    final shortageList = <String>[];

    product.parts.forEach((partId, qty) {
      final part = _partService.getPartById(partId);
      final totalNeeded = qty * order.quantity;
      if (part == null || part.quantity < totalNeeded) {
        hasShortage = true;
        shortageList.add(part?.name ?? 'Unknown Part');
      }
    });

    if (hasShortage) {
      final force = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n?.translate('partsShortageTitle') ?? 'Shortage!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n?.translate('partsShortageContent') ?? 'Insufficient parts:'),
              const SizedBox(height: 8),
              ...shortageList.map((p) => Text('• $p', style: const TextStyle(color: Colors.red))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), 
              child: Text(l10n?.translate('cancel') ?? 'Cancel')
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), 
              child: Text(l10n?.translate('force') ?? 'Force')
            ),
          ],
        ),
      );
      if (force != true) return;
    }

    final success = await _orderService.completeOrder(order, isForce: hasShortage);
    if (success) _refresh();
  }

  Future<void> _incrementOrder(BuildContext context, data.Order order) async {
    final success = await _orderService.partiallyCompleteOrder(order.id, order.completedQuantity + 1);
    if (success) _refresh();
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}