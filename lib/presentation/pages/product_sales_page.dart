/// Product Sales History Page
/// 
/// WHY: Shows which products were sold to which departments
/// Displays: Product name, department name, quantity, sold by, date

import 'package:flutter/material.dart';
import '../../domain/entities/product_sale.dart';
import '../../infrastructure/datasources/supabase_product_sales_datasource.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class ProductSalesPage extends StatefulWidget {
  final String? productId;
  final String? productName;

  const ProductSalesPage({
    super.key,
    this.productId,
    this.productName,
  });

  @override
  State<ProductSalesPage> createState() => _ProductSalesPageState();
}

class _ProductSalesPageState extends State<ProductSalesPage> {
  final SupabaseProductSalesDatasource _salesDatasource = SupabaseProductSalesDatasource();
  bool _isLoading = true;
  List<ProductSale> _sales = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = widget.productId != null
        ? await _salesDatasource.getProductSales(widget.productId!)
        : await _salesDatasource.getAllSales();

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
      (sales) {
        setState(() {
          _isLoading = false;
          _sales = sales;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product Sales'),
            if (widget.productName != null)
              Text(
                widget.productName!,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSales,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _sales.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No sales history available',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSales,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sales.length,
                        itemBuilder: (context, index) {
                          final sale = _sales[index];
                          return _buildSaleCard(sale);
                        },
                      ),
                    ),
    );
  }

  Widget _buildSaleCard(ProductSale sale) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          child: const Icon(
            Icons.shopping_cart,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          sale.productName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.business, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text('${sale.departmentName}'),
              ],
            ),
            const SizedBox(height: 4),
            if (sale.soldByName != null) ...[
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Sold by: ${sale.soldByName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              dateFormat.format(sale.soldAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${sale.quantity}',
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

















