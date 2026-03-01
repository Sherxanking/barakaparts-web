import 'package:flutter/material.dart';
import '../../data/services/order_service.dart';
import '../../domain/entities/user.dart' as domain_user;
import '../../l10n/app_localizations.dart';

class CourierAssignmentDialog extends StatefulWidget {
  final String orderId;
  final int orderQuantity;
  final Function(String courierId, int quantity) onAssign;

  const CourierAssignmentDialog({
    super.key,
    required this.orderId,
    required this.orderQuantity,
    required this.onAssign,
  });

  @override
  State<CourierAssignmentDialog> createState() => _CourierAssignmentDialogState();
}

class _CourierAssignmentDialogState extends State<CourierAssignmentDialog> {
  final OrderService _orderService = OrderService();
  List<domain_user.User> _couriers = [];
  String? _selectedCourier;
  int _selectedQuantity = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCouriers();
  }

  Future<void> _loadCouriers() async {
    try {
      final allUsers = await _orderService.getWorkers();
      // Filter only couriers
      final couriers = allUsers.where((user) => user.isCourier).toList();
      setState(() {
        _couriers = couriers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error loading couriers: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.translate('assignCourier') ?? 'Kuryer tayinlash',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_couriers.isEmpty)
              Text(l10n?.translate('noCouriersAvailable') ?? 'Kuryerlar topilmadi')
            else ...[
              // Courier selection dropdown
              Text(
                l10n?.translate('selectCourier') ?? 'Kuryerni tanlang:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCourier,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: l10n?.translate('courier') ?? 'Kuryer',
                ),
                items: _couriers.map((courier) {
                  return DropdownMenuItem(
                    value: courier.id,
                    child: Text(courier.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCourier = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Quantity selection
              Text(
                l10n?.translate('quantityToTake') ?? 'Olinadigan miqdor:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _selectedQuantity > 1
                        ? () {
                            setState(() {
                              _selectedQuantity--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$_selectedQuantity/${widget.orderQuantity}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: _selectedQuantity < widget.orderQuantity
                        ? () {
                            setState(() {
                              _selectedQuantity++;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n?.translate('cancel') ?? 'Bekor qilish'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedCourier != null && _selectedQuantity > 0
                      ? () {
                          widget.onAssign(_selectedCourier!, _selectedQuantity);
                          Navigator.pop(context);
                        }
                      : null,
                  child: Text(l10n?.translate('assign') ?? 'Tayinlash'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}