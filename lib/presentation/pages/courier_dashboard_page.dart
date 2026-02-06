/// Courier Dashboard Page
/// 
/// Bu sahifa olib ketuvchilar (couriers/drivers) uchun. 
/// Ular olib ketayotgan orderlarni belgilash va ularni completed qilish imkonini beradi.
import 'package:flutter/material.dart';
import '../../core/services/auth_state_service.dart';
import '../../domain/entities/order.dart' as domain;
import '../../domain/entities/user.dart' as domain_user;
import '../../data/services/order_service.dart';
import '../../l10n/app_localizations.dart';

class CourierDashboardPage extends StatefulWidget {
  const CourierDashboardPage({super.key});

  @override
  State<CourierDashboardPage> createState() => _CourierDashboardPageState();
}

class _CourierDashboardPageState extends State<CourierDashboardPage> {
  final OrderService _orderService = OrderService();
  List<domain.Order> _assignedOrders = [];
  List<String> _selectedOrderIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedOrders();
  }

  /// Tayinlangan orderlarni yuklash
  Future<void> _loadAssignedOrders() async {
    final currentUser = AuthStateService().currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Courier sifatida tayinlangan orderlarni olish
      final orders = await _orderService.getOrdersByWorker(currentUser.id);
      
      // Domain entityga o'tkazish (modeldan)
      final domainOrders = orders.map((order) => domain.Order(
        id: order.id,
        productId: order.productName, // Temporary fallback
        productName: order.productName,
        quantity: order.quantity,
        completedQuantity: order.completedQuantity,
        departmentId: order.departmentId,
        status: order.status,
        workerId: order.workerId,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
        completedAt: order.completedAt,
        completedBy: order.completedBy,
        soldTo: order.soldTo,
      )).toList();

      setState(() {
        _assignedOrders = domainOrders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Xatolik yuz berdi: $e');
    }
  }

  /// Order tanlash/olish
  void _toggleOrderSelection(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
    });
  }

  /// Tanlangan orderlarni completed qilish
  Future<void> _completeSelectedOrders() async {
    if (_selectedOrderIds.isEmpty) {
      _showError('Hech qanday order tanlanmagan');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tasdiqlash'),
        content: Text('Siz ${_selectedOrderIds.length} ta orderlarni completed qilmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tasdiqlash'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        int completedCount = 0;
        
        // Order modelini olish va complete qilish
        for (final orderId in _selectedOrderIds) {
          final orderModel = _orderService.getOrderById(orderId);
          if (orderModel != null) {
            final result = await _orderService.completeOrder(orderModel);
            if (result) {
              completedCount++;
            }
          }
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _selectedOrderIds.clear();
          });
          
          _showSuccess('$completedCount ta order completed qilindi');
          _loadAssignedOrders(); // Yangilash
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showError('Xatolik yuz berdi: $e');
      }
    }
  }

  /// Tanlashni tozalash
  void _clearSelection() {
    setState(() {
      _selectedOrderIds.clear();
    });
  }

  /// Xato xabarini ko'rsatish
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Muvaffaqiyat xabarini ko'rsatish
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthStateService().currentUser;
    
    // Faqat courierlar uchun
    if (currentUser == null || (!currentUser.isCourier && !currentUser.isWorker && !currentUser.isManager)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Courier Dashboard')),
        body: const Center(
          child: Text('Sizda bu sahifaga kirish huquqi yo\'q'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courier Dashboard'),
        actions: [
          if (_selectedOrderIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Tanlovni tozalash',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tanlanganlar soni va action button
                if (_selectedOrderIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue.shade50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedOrderIds.length} ta order tanlangan',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _completeSelectedOrders,
                          icon: const Icon(Icons.check),
                          label: const Text('Complete Selected'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Orderlar ro'yxati
                Expanded(
                  child: _assignedOrders.isEmpty
                      ? const Center(
                          child: Text('Sizga hech qanday order tayinlanmagan'),
                        )
                      : ListView.builder(
                          itemCount: _assignedOrders.length,
                          itemBuilder: (context, index) {
                            final order = _assignedOrders[index];
                            final isSelected = _selectedOrderIds.contains(order.id);
                            
                            return Card(
                              color: isSelected ? Colors.blue.shade50 : null,
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) => _toggleOrderSelection(order.id),
                                title: Text(
                                  '${order.productName} (${order.quantity} dona)',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  'Status: ${order.status} | Department: ${order.departmentId}',
                                ),
                                secondary: CircleAvatar(
                                  backgroundColor: _getStatusColor(order.status),
                                  child: Text(
                                    order.status.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  /// Statusga qarab rang qaytarish
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return Colors.orange;
      case 'partially_completed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}