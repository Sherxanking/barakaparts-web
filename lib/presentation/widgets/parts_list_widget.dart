/// Parts List Widget
/// 
/// WHY: Expandable/collapsible parts list for products
/// Shows all parts with expand/collapse functionality

import 'package:flutter/material.dart';
import '../../data/services/part_service.dart';

class PartsListWidget extends StatefulWidget {
  final Map<String, int> parts;
  final PartService partService;

  const PartsListWidget({
    super.key,
    required this.parts,
    required this.partService,
  });

  @override
  State<PartsListWidget> createState() => _PartsListWidgetState();
}

class _PartsListWidgetState extends State<PartsListWidget> {
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
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: displayParts.map((entry) {
            final part = widget.partService.getPartById(entry.key);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.build_circle,
                    size: 14,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${part?.name ?? entry.key}: ${entry.value}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isExpanded 
                        ? 'Yig\'ish' 
                        : '+${partsList.length - _maxCollapsedItems} ta ko\'p',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
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

