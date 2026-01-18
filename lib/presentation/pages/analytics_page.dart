/// Analytics Dashboard Page
/// 
/// WHY: Provides statistics and charts for orders, parts, and products
/// Shows: Monthly production, orders by status, orders by department, low stock alerts

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/services/analytics_service.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../l10n/app_localizations.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = true;
  
  // Statistics
  int _thisMonthProduction = 0;
  Map<String, int> _ordersByStatus = {};
  Map<String, int> _ordersByDepartment = {};
  Map<String, int> _productionByProduct = {}; // Product bo'yicha production
  int _lowStockParts = 0;
  int _totalParts = 0;
  int _totalProducts = 0;
  int _totalDepartments = 0;
  Map<String, int> _monthlyProduction = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    // Load all statistics in parallel
    final thisMonthResult = await _analyticsService.getThisMonthProductionCount();
    final ordersByStatusResult = await _analyticsService.getOrdersCountByStatus();
    final ordersByDeptResult = await _analyticsService.getOrdersCountByDepartment();
    final productionByProductResult = await _analyticsService.getProductionCountByProductNameThisMonth();
    final lowStockResult = await _analyticsService.getLowStockPartsCount();
    final totalPartsResult = await _analyticsService.getTotalPartsCount();
    final totalProductsResult = await _analyticsService.getTotalProductsCount();
    final totalDeptsResult = await _analyticsService.getTotalDepartmentsCount();
    final monthlyResult = await _analyticsService.getProductionCountForLastMonths(6);

    if (!mounted) return;

    // Process results
    thisMonthResult.fold(
      (failure) {},
      (count) => _thisMonthProduction = count,
    );
    
    ordersByStatusResult.fold(
      (failure) {},
      (counts) => _ordersByStatus = counts,
    );
    
    ordersByDeptResult.fold(
      (failure) {},
      (counts) => _ordersByDepartment = counts,
    );
    
    productionByProductResult.fold(
      (failure) {},
      (counts) => _productionByProduct = counts,
    );
    
    lowStockResult.fold(
      (failure) {},
      (count) => _lowStockParts = count,
    );
    
    totalPartsResult.fold(
      (failure) {},
      (count) => _totalParts = count,
    );
    
    totalProductsResult.fold(
      (failure) {},
      (count) => _totalProducts = count,
    );
    
    totalDeptsResult.fold(
      (failure) {},
      (count) => _totalDepartments = count,
    );
    
    monthlyResult.fold(
      (failure) {},
      (counts) => _monthlyProduction = counts,
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('analytics') ?? 'Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    
                    // This Month Production
                    _buildThisMonthProduction(),
                    const SizedBox(height: 24),
                    
                    // Monthly Production Chart
                    _buildMonthlyProductionChart(),
                    const SizedBox(height: 24),
                    
                    // Orders by Status Chart
                    _buildOrdersByStatusChart(),
                    const SizedBox(height: 24),
                    
                    // Orders by Department Chart
                    _buildOrdersByDepartmentChart(),
                    const SizedBox(height: 24),
                    
                    // Production by Product Chart
                    _buildProductionByProductChart(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'This Month',
            '$_thisMonthProduction',
            Icons.production_quantity_limits,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Low Stock',
            '$_lowStockParts',
            Icons.warning,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total Parts',
            '$_totalParts',
            Icons.build,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Products',
            '$_totalProducts',
            Icons.inventory,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThisMonthProduction() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'This Month Production',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$_thisMonthProduction',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            Text(
              'units produced',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyProductionChart() {
    if (_monthlyProduction.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No production data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final entries = _monthlyProduction.entries.toList();
    final maxValue = _monthlyProduction.values.reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Production (Last 6 Months)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final month = entries[groupIndex].key;
                        final value = entries[groupIndex].value;
                        return BarTooltipItem(
                          '$month\n$value',
                          const TextStyle(color: Colors.white),
                        );
                      },
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= entries.length) return const Text('');
                          final month = entries[value.toInt()].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              month.substring(5), // Show only month
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final value = entry.value.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value.toDouble(),
                          color: Colors.blue,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersByStatusChart() {
    if (_ordersByStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = _ordersByStatus.entries.toList();
    final total = _ordersByStatus.values.fold(0, (a, b) => a + b);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orders by Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: entries.map((entry) {
                    final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
                    final colors = {
                      'pending': Colors.orange,
                      'approved': Colors.blue,
                      'completed': Colors.green,
                      'rejected': Colors.red,
                    };
                    
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: '${entry.value}\n(${percentage.toStringAsFixed(1)}%)',
                      color: colors[entry.key] ?? Colors.grey,
                      radius: 80,
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              children: entries.map((entry) {
                final colors = {
                  'pending': Colors.orange,
                  'approved': Colors.blue,
                  'completed': Colors.green,
                  'rejected': Colors.red,
                };
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors[entry.key] ?? Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersByDepartmentChart() {
    if (_ordersByDepartment.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get department names
    // Note: This would require loading departments
    // For now, show IDs
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orders by Department',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._ordersByDepartment.entries.map((entry) {
              final total = _ordersByDepartment.values.fold(0, (a, b) => a + b);
              final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Department ${entry.key.substring(0, 8)}...',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionByProductChart() {
    if (_productionByProduct.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Bu oy uchun mahsulotlar bo\'yicha ma\'lumot yo\'q',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final entries = _productionByProduct.entries.toList();
    // Sort by count descending
    entries.sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.isNotEmpty 
        ? entries.map((e) => e.value).reduce((a, b) => a > b ? a : b)
        : 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Mahsulotlar bo\'yicha ishlab chiqarish (Bu oy)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: entries.length * 60.0, // Dynamic height based on number of products
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (groupIndex >= entries.length) return null;
                        final product = entries[groupIndex].key;
                        final value = entries[groupIndex].value;
                        return BarTooltipItem(
                          '$product\n$value dona',
                          const TextStyle(color: Colors.white),
                        );
                      },
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= entries.length) return const Text('');
                          final product = entries[value.toInt()].key;
                          // Shorten product name if too long
                          final displayName = product.length > 10 
                              ? '${product.substring(0, 10)}...'
                              : product;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: Text(
                                displayName,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          );
                        },
                        reservedSize: 60,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final value = entry.value.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value.toDouble(),
                          color: Colors.purple,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Product list with counts
            ...entries.map((entry) {
              final total = entries.map((e) => e.value).fold(0, (a, b) => a + b);
              final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.value} dona (${percentage.toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

