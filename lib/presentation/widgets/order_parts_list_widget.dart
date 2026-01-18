/// Order Parts List Widget
/// 
/// WHY: Chiroyli expandable/collapsible parts list for orders
/// Shows parts used in an order with badges and expand/collapse functionality

import 'package:flutter/material.dart';
import '../../data/services/part_service.dart';

class OrderPartsListWidget extends StatefulWidget {
  final Map<String, int> parts;
  final int orderQuantity;
  final PartService partService;

  const OrderPartsListWidget({
    super.key,
    required this.parts,
    required this.orderQuantity,
    required this.partService,
  });

  @override
  State<OrderPartsListWidget> createState() => _OrderPartsListWidgetState();
}

class _OrderPartsListWidgetState extends State<OrderPartsListWidget> {
  bool _isExpanded = false;
  static const int _maxCollapsedItems = 3;

  @override
  Widget build(BuildContext context) {
    final partsList = widget.parts.entries.toList();
    final shouldShowExpand = partsList.length > _maxCollapsedItems;
    final displayParts = _isExpanded 
        ? partsList 
        : partsList.take(_maxCollapsedItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: displayParts.map((entry) {
            final part = widget.partService.getPartById(entry.key);
            final qtyPerProduct = entry.value;
            final totalQty = qtyPerProduct * widget.orderQuantity;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.shade200,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Part icon
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.build_circle,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Part name
                    Expanded(
                      child: Text(
                        part?.name ?? entry.key,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Total quantity badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.shade300,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '$totalQty ta',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (shouldShowExpand)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isExpanded 
                        ? 'Yig\'ish' 
                        : '+${partsList.length - _maxCollapsedItems} ta ko\'p',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

