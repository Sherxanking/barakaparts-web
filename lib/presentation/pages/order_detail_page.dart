import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';
import '../../data/models/department_model.dart';
import '../../data/services/department_service.dart';
import '../../data/services/order_service.dart';
import '../../data/services/part_service.dart'; // Import PartService
import '../../core/di/service_locator.dart'; // Import ServiceLocator
import '../widgets/order_parts_list_widget.dart';
import '../../l10n/app_localizations.dart';

class OrderDetailPage extends StatelessWidget {
  final String orderId;
  final OrderService _orderService = OrderService();
  final DepartmentService _departmentService = DepartmentService();
  final PartService _partService = PartService(); // Add PartService

  OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final order = _orderService.getOrderById(orderId);
    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Not Found')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final department = _departmentService.getDepartmentById(order.departmentId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order Details'),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Order Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Product Name
                      _buildInfoRow(
                        Icons.inventory,
                        'Product',
                        order.productName,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Department
                      if (department != null)
                        _buildInfoRow(
                          Icons.business,
                          'Department',
                          department.name,
                        ),
                      
                      const SizedBox(height: 8),
                      
                      // Quantity
                      _buildInfoRow(
                        Icons.numbers,
                        'Quantity',
                        '${order.quantity}',
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Status
                      _buildInfoRow(
                        Icons.label,
                        'Status',
                        order.status,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Created Date
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Created',
                        order.createdAt.toString().substring(0, 16),
                      ),
                      
                      // Started Date
                      if (order.startedAt != null)
                        _buildInfoRow(
                          Icons.play_arrow,
                          'Started',
                          order.startedAt!.toString().substring(0, 16),
                        ),
                      
                      // Completed Date
                      if (order.completedAt != null)
                        _buildInfoRow(
                          Icons.check_circle_outline,
                          'Completed',
                          order.completedAt!.toString().substring(0, 16),
                        ),
                      
                      // Fully Completed Date
                      if (order.fullyCompletedAt != null)
                        _buildInfoRow(
                          Icons.check_circle,
                          'Fully Completed',
                          order.fullyCompletedAt!.toString().substring(0, 16),
                        ),
                      
                      // Duration
                      if (order.durationHours != null)
                        _buildInfoRow(
                          Icons.timer,
                          'Duration',
                          '${order.durationHours!.toStringAsFixed(1)} hours',
                        ),
                      
                      // Sold To
                      if (order.soldTo != null && order.soldTo!.isNotEmpty)
                        _buildInfoRow(
                          Icons.person,
                          'Sold To',
                          order.soldTo!,
                        ),
                      
                      // Notes
                      if (order.notes != null && order.notes!.isNotEmpty)
                        _buildInfoRow(
                          Icons.note,
                          'Notes',
                          order.notes!,
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Parts Required Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parts Required',
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
                        partService: _partService, // Use instance variable
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Taken Items Card
              if (order.takenItems.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Taken Items',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // List of taken items
                        ...order.takenItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final takenItem = entry.value;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Colors.green[50],
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green[700],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Item ${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Quantity
                                  _buildInfoRow(
                                    Icons.numbers,
                                    'Quantity',
                                    '${takenItem.quantity}',
                                  ),
                                  
                                  // Courier/Taker
                                  _buildInfoRow(
                                    Icons.person,
                                    'Courier/Taker',
                                    takenItem.courierId,
                                  ),
                                  
                                  // Taken At
                                  _buildInfoRow(
                                    Icons.access_time,
                                    'Taken At',
                                    takenItem.takenAt.toString().substring(0, 16),
                                  ),
                                  
                                  // Notes
                                  if (takenItem.notes != null && takenItem.notes!.isNotEmpty)
                                    _buildInfoRow(
                                      Icons.note,
                                      'Notes',
                                      takenItem.notes!,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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