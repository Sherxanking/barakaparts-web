/// Order History Page
/// 
/// WHY: Shows all orders with "Kimga sotilgan" information
/// Displays: Order details, sold to, status, date

import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/order.dart' as domain;
import '../../data/models/department_model.dart';
import '../../data/services/department_service.dart';
import '../../l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class OrderHistoryPage extends StatefulWidget {
  final List<domain.Order> orders;

  const OrderHistoryPage({
    super.key,
    required this.orders,
  });

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final DepartmentService _departmentService = DepartmentService();
  String? _selectedStatusFilter;
  String? _selectedDepartmentFilter;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer; // Debounce timer

  // Statistics
  int _completedToday = 0;
  int _completedThisWeek = 0;
  int _completedThisMonth = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _calculateStats();
  }

  void _calculateStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    int countToday = 0;
    int countWeek = 0;
    int countMonth = 0;

    for (final order in widget.orders) {
      if (order.status == 'completed') {
        final date = order.updatedAt ?? order.createdAt;
        final dateOnly = DateTime(date.year, date.month, date.day);
        
        if (!dateOnly.isBefore(startOfMonth)) {
          countMonth += order.quantity;
          
          if (!dateOnly.isBefore(startOfWeek)) {
            countWeek += order.quantity;
            
            if (!dateOnly.isBefore(today)) {
              countToday += order.quantity;
            }
          }
        }
      }
    }

    setState(() {
      _completedToday = countToday;
      _completedThisWeek = countWeek;
      _completedThisMonth = countMonth;
    });
  }

  void _onSearchChanged() {
    // Debounce: 300ms kutish
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<domain.Order> _getFilteredOrders() {
    var orders = widget.orders;

    // Status filter
    if (_selectedStatusFilter != null) {
      orders = orders.where((o) => o.status == _selectedStatusFilter).toList();
    }

    // Department filter
    if (_selectedDepartmentFilter != null) {
      orders = orders.where((o) => o.departmentId == _selectedDepartmentFilter).toList();
    }

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      orders = orders.where((o) {
        return o.productName.toLowerCase().contains(query) ||
            (o.soldTo != null && o.soldTo!.toLowerCase().contains(query));
      }).toList();
    }

    // Sort by date (newest first)
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return orders;
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _getFilteredOrders();
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        elevation: 2,
      ),
      body: Column(
        children: [
          // Quick Stats (Today, This Week, This Month)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatColumn('Bugun', _completedToday.toString(), Colors.blue),
                _buildStatColumn('Shu hafta', _completedThisWeek.toString(), Colors.orange),
                _buildStatColumn('Shu oy', _completedThisMonth.toString(), Colors.green),
              ],
            ),
          ),
          const Divider(height: 1),
          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Qidirish (mahsulot, kimga sotilgan...)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) {
                    // Debounce is handled in listener
                  },
                ),
                const SizedBox(height: 12),
                // Status filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Barchasi', null, _selectedStatusFilter == null),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', 'pending', _selectedStatusFilter == 'pending'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed', 'completed', _selectedStatusFilter == 'completed'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Orders list
          Expanded(
            child: filteredOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Orderlar topilmadi',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      final department = _departmentService.getDepartmentById(order.departmentId);
                      final statusColor = order.status == 'completed'
                          ? Colors.green
                          : order.status == 'pending'
                              ? Colors.orange
                              : Colors.red;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              order.status == 'completed'
                                  ? Icons.check_circle
                                  : order.status == 'pending'
                                      ? Icons.pending
                                      : Icons.cancel,
                              color: statusColor.shade700,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            order.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Miqdor: ${order.quantity}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (department != null)
                                Text(
                                  'Bo\'lim: ${department.name}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              Text(
                                dateFormat.format(order.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Status
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: statusColor.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          order.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: statusColor.shade900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Sold To (if exists)
                                  if (order.soldTo != null && order.soldTo!.isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.purple.shade200,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.person,
                                              size: 18,
                                              color: Colors.purple.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Kimga sotilgan',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.purple.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  order.soldTo!,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.purple.shade900,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person_outline,
                                            size: 18,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Kimga sotilgan ko\'rsatilmagan',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  // Created date
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Yaratilgan: ${dateFormat.format(order.createdAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (order.updatedAt != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.update,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Yangilangan: ${dateFormat.format(order.updatedAt!)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (isSelected) {
        setState(() {
          _selectedStatusFilter = isSelected ? value : null;
        });
      },
    );
  }

  Widget _buildStatColumn(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}


