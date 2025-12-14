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
import '../widgets/status_badge_widget.dart';
import '../widgets/animated_list_item.dart';

class OrderItemWidget extends StatelessWidget {
  final Order order;
  final Department? department;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const OrderItemWidget({
    super.key,
    required this.order,
    this.department,
    required this.onComplete,
    required this.onDelete,
  });

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
                      'Quantity: ${order.quantity}',
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
                      'Created: ${order.createdAt.toString().substring(0, 16)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Complete button (only for pending orders)
                    if (order.status == 'pending')
                      TextButton.icon(
                        onPressed: onComplete,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Complete'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Delete button
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDelete,
                      tooltip: 'Delete Order',
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
}

