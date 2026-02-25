/// Analytics Dashboard Page
/// 
/// WHY: Provides statistics and charts for orders, parts, and products
/// Shows: Monthly production, orders by status, orders by department, low stock alerts

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/order_service.dart'; // OrderService import qo'shildi
import '../../domain/entities/part.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../core/di/service_locator.dart';
import '../../l10n/app_localizations.dart';
import '../pages/settings_page.dart';

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
  int _thisMonthPartsUsed = 0;
  Map<String, int> _ordersByStatus = {};
  Map<String, int> _ordersByDepartment = {};
  Map<String, int> _productionByProduct = {}; // Product bo'yicha production
  int _lowStockParts = 0;
  List<Part> _lowStockPartsList = [];
  Map<String, int> _topUsedParts = {};
  int _totalParts = 0;
  int _totalProducts = 0;
  int _totalDepartments = 0;
  Map<String, int> _monthlyProduction = {};
  Map<String, double> _avgCompletionTimeByDepartment = {}; // Average completion time by department
  
  // Missing fields restored
  double _averageCompletionTime = 0.0;
  Map<String, double> _avgCompletionTimeByProduct = {};
  
  // KPI and Product focus
  List<Map<String, dynamic>> _workerKPIs = [];
  Map<String, dynamic>? _selectedProductProgress;
  String? _selectedProductId;
  Map<String, int> _selectedProductGrowth = {};
  List<dynamic> _allProducts = []; // List of products for selection

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
    final ordersByDeptResult = await _analyticsService.getOrdersQuantityByDepartmentForMonth(DateTime.now());
    final productionByProductResult = await _analyticsService.getProductionCountByProductNameThisMonth();
    final lowStockResult = await _analyticsService.getLowStockPartsCount();
    final lowStockListResult = await _analyticsService.getLowStockPartsList();
    final totalPartsResult = await _analyticsService.getTotalPartsCount();
    final totalProductsResult = await _analyticsService.getTotalProductsCount();
    final totalDeptsResult = await _analyticsService.getTotalDepartmentsCount();
    final monthlyResult = await _analyticsService.getProductionCountForLastMonths(6);
    final partsUsageResult = await _analyticsService.getPartsUsageByNameForMonth(DateTime.now(), limit: 10);
    final totalPartsUsedResult = await _analyticsService.getTotalPartsUsedForMonth(DateTime.now());

    // Load time tracking statistics
    final orderService = OrderService();
    _averageCompletionTime = orderService.getAverageCompletionTime();
    _avgCompletionTimeByProduct = _calculateAvgCompletionTimeByProduct();
    _avgCompletionTimeByDepartment = _calculateAvgCompletionTimeByDepartment();

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
    
    lowStockListResult.fold(
      (failure) {},
      (parts) => _lowStockPartsList = parts,
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
    
    partsUsageResult.fold(
      (failure) {},
      (usage) => _topUsedParts = usage,
    );
    
    totalPartsUsedResult.fold(
      (failure) {},
      (total) => _thisMonthPartsUsed = total,
    );

    // Load new KPI and Product analytics
    final workerKPIsResult = await _analyticsService.getWorkerKPIs();
    workerKPIsResult.fold(
      (failure) {},
      (stats) => _workerKPIs = stats,
    );

    // Set first product as default if none selected
    final productsResult = await ServiceLocator.instance.productRepository.getAllProducts();
    productsResult.fold(
      (failure) {},
      (products) {
        _allProducts = products;
        if (_selectedProductId == null && products.isNotEmpty) {
          _selectedProductId = products.first.id;
        }
      },
    );

    if (_selectedProductId != null) {
      final progressResult = await _analyticsService.getProductProgress(_selectedProductId!);
      progressResult.fold(
        (failure) {},
        (stats) => _selectedProductProgress = stats,
      );

      final growthResult = await _analyticsService.getProductGrowth(_selectedProductId!);
      growthResult.fold(
        (failure) {},
        (growth) => _selectedProductGrowth = growth,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Calculate average completion time by product
  Map<String, double> _calculateAvgCompletionTimeByProduct() {
    final orderService = OrderService();
    final orders = orderService.getOrdersWithTimeTracking()
        .where((order) => order.hasStarted && order.isFullyCompleted)
        .toList();
    
    final Map<String, List<double>> timeMap = {};
    
    for (final order in orders) {
      final duration = order.getDurationInHours();
      if (duration != null) {
        timeMap.putIfAbsent(order.productName, () => []).add(duration);
      }
    }
    
    final Map<String, double> result = {};
    timeMap.forEach((productName, durations) {
      result[productName] = durations.reduce((a, b) => a + b) / durations.length;
    });
    
    return result;
  }

  /// Calculate average completion time by department
  Map<String, double> _calculateAvgCompletionTimeByDepartment() {
    final orderService = OrderService();
    final orders = orderService.getOrdersWithTimeTracking()
        .where((order) => order.hasStarted && order.isFullyCompleted)
        .toList();
    
    final Map<String, List<double>> timeMap = {};
    
    for (final order in orders) {
      final duration = order.getDurationInHours();
      if (duration != null) {
        timeMap.putIfAbsent(order.departmentId, () => []).add(duration);
      }
    }
    
    final Map<String, double> result = {};
    timeMap.forEach((departmentId, durations) {
      result[departmentId] = durations.reduce((a, b) => a + b) / durations.length;
    });
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('analytics') ?? 'Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            tooltip: 'Settings',
          ),
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

                    // Product Focus Section (New)
                    _buildProductFocusSection(),
                    const SizedBox(height: 24),
                    
                    // This Month Production
                    _buildThisMonthProduction(),
                    const SizedBox(height: 24),
                    
                    // This Month Parts Used
                    _buildThisMonthPartsUsed(),
                    const SizedBox(height: 24),
                    
                    // Monthly Production Chart
                    _buildMonthlyProductionChart(),
                    const SizedBox(height: 24),
                    
                    // Orders by Status Chart
                    _buildOrdersByStatusChart(),
                    const SizedBox(height: 24),

                    // Worker KPI Section (New)
                    _buildWorkerKPISection(),
                    const SizedBox(height: 24),
                    
                    // Orders by Department Chart
                    _buildOrdersByDepartmentChart(),
                    const SizedBox(height: 24),
                    
                    // Production by Product Chart
                    _buildProductionByProductChart(),
                    const SizedBox(height: 24),
                    
                    // Time Tracking Analytics
                    _buildTimeTrackingAnalytics(),
                    const SizedBox(height: 24),
                    
                    // Courier Analytics
                    _buildCourierAnalytics(),
                    const SizedBox(height: 24),
                    
                    // Latest Ready Orders
                    _buildLatestReadyOrders(),
                    const SizedBox(height: 24),
                    
                    // In Progress Orders
                    _buildInProgressOrders(),
                    const SizedBox(height: 24),
                    
                    // Top Used Parts (This Month)
                    _buildTopUsedPartsList(),
                    const SizedBox(height: 24),
                    
                    // Low Stock Parts List
                    _buildLowStockPartsList(),
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
            const SizedBox(height: 16),
            // Product breakdown
            if (_productionByProduct.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Product breakdown:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ..._productionByProduct.entries.map((entry) {
                final percentage = _thisMonthProduction > 0 
                    ? (entry.value / _thisMonthProduction * 100).round()
                    : 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${entry.value} (${percentage}%)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'No product breakdown available',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildThisMonthPartsUsed() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'This Month Parts Usage',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$_thisMonthPartsUsed',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            Text(
              'total parts used',
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
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Production by Department (This Month)',
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
                          entry.key,
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
                  'Ishlab chiqarish (Bu oy)',
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
  
  Widget _buildTopUsedPartsList() {
    if (_topUsedParts.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No parts usage data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }
    
    final entries = _topUsedParts.entries.toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Top Parts Used (This Month)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
                      '${entry.value}',
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
  
  Widget _buildLowStockPartsList() {
    if (_lowStockPartsList.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No low stock parts',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Low Stock Parts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._lowStockPartsList.map((part) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        part.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${part.quantity} / ${part.minQuantity}',
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

  Widget _buildTimeTrackingAnalytics() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Time Tracking Analytics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Average Completion Time
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Average Completion Time',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_averageCompletionTime.toStringAsFixed(2)} hours',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Average Completion Time by Product
            if (_avgCompletionTimeByProduct.isNotEmpty) ...[
              const Text(
                'Average Completion Time by Product',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ..._avgCompletionTimeByProduct.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${entry.value.toStringAsFixed(2)}h',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
            
            // Average Completion Time by Department
            if (_avgCompletionTimeByDepartment.isNotEmpty) ...[
              const Text(
                'Average Completion Time by Department',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ..._avgCompletionTimeByDepartment.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${entry.value.toStringAsFixed(2)}h',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCourierAnalytics() {
    final orderService = OrderService();
    final analytics = orderService.getCourierAnalytics();
    
    if (analytics.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.delivery_dining, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Courier Analytics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'No courier assignment data available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Courier Analytics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...analytics.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '\${entry.value} items',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.right,
                      ),
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

  Widget _buildLatestReadyOrders() {
    final orderService = OrderService();
    final recentOrders = orderService.getRecentlyCompletedOrders(limit: 5);
    
    if (recentOrders.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'So\'nggi tayyor buyurtmalar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Hozircha tayyor buyurtmalar yo\'q',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'So\'nggi tayyor buyurtmalar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recentOrders.map((order) {
              final completedAt = order.completedAt ?? order.updatedAt ?? order.createdAt;
              final timeDiff = DateTime.now().difference(completedAt);
              String timeAgo;
              
              if (timeDiff.inDays > 0) {
                timeAgo = '\${timeDiff.inDays} kun oldin';
              } else if (timeDiff.inHours > 0) {
                timeAgo = '\${timeDiff.inHours} soat oldin';
              } else {
                timeAgo = '\${timeDiff.inMinutes} daqiqa oldin';
              }
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, size: 16, color: Colors.green[700]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\${order.quantity} ta \${order.productName}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Bo\'lim: \${order.departmentId} • \$timeAgo',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
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

  Widget _buildInProgressOrders() {
    final orderService = OrderService();
    final inProgressOrders = orderService.getInProgressOrders(limit: 5);
    
    if (inProgressOrders.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hourglass_top, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Jarayondagi buyurtmalar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Hozircha jarayondagi buyurtmalar yo\'q',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_top, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Jarayondagi buyurtmalar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...inProgressOrders.map((order) {
              final startedAt = order.startedAt ?? order.updatedAt ?? order.createdAt;
              final timeDiff = DateTime.now().difference(startedAt);
              String timeAgo;
              
              if (timeDiff.inDays > 0) {
                timeAgo = '\${timeDiff.inDays} kun oldin';
              } else if (timeDiff.inHours > 0) {
                timeAgo = '\${timeDiff.inHours} soat oldin';
              } else {
                timeAgo = '\${timeDiff.inMinutes} daqiqa oldin';
              }
              
              // Calculate completion percentage
              final percentage = order.quantity > 0 
                  ? (order.completedQuantity / order.quantity * 100).round()
                  : 0;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.hourglass_bottom, size: 16, color: Colors.orange[700]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\${order.completedQuantity}/\${order.quantity} \${order.productName} (\$percentage%)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Bo\'lim: \${order.departmentId} • \$timeAgo',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        ],
                      ),
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

  // --- NEW SECTIONS ---

  /// FOCUS PRODUCT SECTION
  Widget _buildProductFocusSection() {
    if (_allProducts.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mahsulot Analitikasi',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Dropdown to select product
                Container(
                  constraints: const BoxConstraints(maxWidth: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedProductId,
                      items: _allProducts.map((p) {
                        final String id = (p is Map) ? p['id'] : (p as dynamic).id;
                        final String name = (p is Map) ? p['name'] : (p as dynamic).name;
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            name, 
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _onProductChanged,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (_selectedProductProgress != null) ...[
              // Plan vs Actual Score
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progress', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      Text(
                        '${_selectedProductProgress!['percent']}%',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Plan: ${_selectedProductProgress!['totalPlan']} dona', 
                           style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('Tayyor: ${_selectedProductProgress!['actual']} dona', 
                           style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Custom Status Bar
              _buildProgressFunnelBar(),
              const SizedBox(height: 12),
              
              // Legend
              _buildStatusLegend(),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // Growth Chart for this product
              Text('Oylik ishlab chiqarish o\'sishi', 
                   style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: _buildProductGrowthChart(),
              ),
            ] else 
              const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressFunnelBar() {
    final stats = _selectedProductProgress!;
    final int taken = stats['taken'];
    final int ready = stats['ready'];
    final int inProgress = stats['inProgress'];
    final int total = stats['totalPlan'];
    final int remaining = (total - (taken + ready + inProgress)).clamp(0, 1000000);

    return Container(
      height: 28,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            if (taken > 0) Expanded(flex: taken, child: Container(color: Colors.green, child: Center(child: Text(taken > total * 0.1 ? 'Olib ketildi' : 'O', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)))),
            if (ready > 0) Expanded(flex: ready, child: Container(color: Colors.blue, child: Center(child: Text(ready > total * 0.1 ? 'Tayyor' : 'T', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)))),
            if (inProgress > 0) Expanded(flex: inProgress, child: Container(color: Colors.orange, child: Center(child: Text(inProgress > total * 0.1 ? 'Jarayonda' : 'J', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)))),
            if (remaining > 0) Expanded(flex: remaining, child: Container(color: Colors.grey[300])),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLegend() {
    final stats = _selectedProductProgress!;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendItem('Olib ketildi', Colors.green, stats['taken']),
        _legendItem('Tayyor', Colors.blue, stats['ready']),
        _legendItem('Jarayonda', Colors.orange, stats['inProgress']),
        _legendItem('Kutilmoqda', Colors.grey[400]!, (stats['totalPlan'] - (stats['taken'] + stats['ready'] + stats['inProgress']) as int).clamp(0, 1000000)),
      ],
    );
  }

  Widget _legendItem(String label, Color color, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(fontSize: 12)),
        Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildProductGrowthChart() {
    if (_selectedProductGrowth.isEmpty) {
      return const Center(child: Text('Ma\'lumot yo\'q'));
    }

    final entries = _selectedProductGrowth.entries.toList();
    final List<FlSpot> spots = [];
    for (int i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                final key = entries[index].key; // YYYY-MM
                final month = key.split('-')[1];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(month, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
              reservedSize: 22,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  /// WORKER KPI SECTION
  Widget _buildWorkerKPISection() {
    if (_workerKPIs.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.deepPurple, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Ishchilar KPI (Samaradorlik)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _workerKPIs.length > 5 ? 5 : _workerKPIs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final kpi = _workerKPIs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getWorkerColor(index),
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(kpi['workerName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${kpi['position'] ?? kpi['role']}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${kpi['completedQuantity']} dona',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                    ),
                    Text(
                      'Avg: ${kpi['avgHoursPerOrder'].toStringAsFixed(1)}s/order',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_workerKPIs.length > 5)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // Show full list dialog?
                  },
                  child: const Text('Barchasini ko\'rish'),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Color _getWorkerColor(int index) {
    if (index == 0) return Colors.amber; // Gold
    if (index == 1) return Colors.grey[400]!; // Silver
    if (index == 2) return Colors.brown[300]!; // Bronze
    return Colors.blue[300]!;
  }

  Future<void> _onProductChanged(String? productId) async {
    if (productId == null) return;
    
    setState(() {
      _selectedProductId = productId;
      _selectedProductProgress = null;
    });

    final progressResult = await _analyticsService.getProductProgress(productId);
    final growthResult = await _analyticsService.getProductGrowth(productId);

    if (mounted) {
      setState(() {
        progressResult.fold((_) => null, (stats) => _selectedProductProgress = stats);
        growthResult.fold((_) => null, (growth) => _selectedProductGrowth = growth);
      });
    }
  }
}


