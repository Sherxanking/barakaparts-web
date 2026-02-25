/// HomePage - Asosiy navigatsiya sahifasi
/// 
/// Bu sahifa bottom navigation bar orqali 4 ta asosiy sahifani boshqaradi:
/// - Orders: Buyurtmalar
/// - Departments: Bo'limlar
/// - Products: Mahsulotlar
/// - Parts: Qismlar
/// 
/// Page transitions animatsiyalari bilan jihozlangan.
import  'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/part_model.dart';
import '../../data/services/hive_box_service.dart';
import '../../core/di/service_locator.dart';
import '../../domain/repositories/part_repository.dart';
import '../../domain/entities/part.dart';
import '../../l10n/app_localizations.dart';
import '../../core/services/auth_state_service.dart';
import 'orders_page.dart';
import 'departments_page.dart';
import 'parts_page.dart';
import 'products_page.dart';
import 'settings_page.dart';
import 'analytics_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys;
  final HiveBoxService _boxService = HiveBoxService();
  final PartRepository _partRepository = ServiceLocator.instance.partRepository;

  @override
  void initState() {
    super.initState();
    // Har bir sahifa uchun navigator key yaratish
    _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
    // Refresh cache once at startup to reduce badge mismatch
    _refreshPartsCache();
    
    // Sahifalarni yaratish
    _pages = [
      AnalyticsPage(key: _navigatorKeys[0]),
      PartsPage(key: _navigatorKeys[1]),
      OrdersPage(key: _navigatorKeys[2]),
      DepartmentsPage(key: _navigatorKeys[3]),
      ProductsPage(key: _navigatorKeys[4]),
    ];
  }
  
  Future<void> _refreshPartsCache() async {
    try {
      final result = await _partRepository.getAllParts();
      result.fold(
        (_) {},
        (parts) async {
          if (!Hive.isBoxOpen('partsBox')) {
            await Hive.openBox<PartModel>('partsBox');
          }
          final box = Hive.box<PartModel>('partsBox');
          await box.clear();
          for (final Part part in parts) {
            final model = PartModel(
              id: part.id,
              name: part.name,
              quantity: part.quantity,
              minQuantity: part.minQuantity ?? 3,
              imagePath: part.imagePath,
              status: part.quantity <= (part.minQuantity ?? 3)
                  ? 'lowstock'
                  : 'available',
            );
            await box.add(model);
          }
        },
      );
    } catch (_) {
      // Ignore cache refresh errors
    }
  }

  /// Kam qolgan qismlarni olish
  int _getLowStockCount() {
    try {
      final partsBox = _boxService.partsBox;
      // Align with Part.isLowStock (<= minQuantity) for consistent counts
      return partsBox.values.where((part) => part.quantity <= part.minQuantity).length;
    } catch (e) {
      return 0;
    }
  }

  BottomNavigationBarItem _buildNavItem(
    int index,
    AppLocalizations? l10n,
    int lowStockCount,
  ) {
    switch (index) {
      case 0:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.analytics),
          activeIcon: const Icon(Icons.analytics),
          label: l10n?.translate('analytics') ?? 'Analytics',
        );
      case 1:
        return BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.build),
              if (lowStockCount > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$lowStockCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          activeIcon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.build),
              if (lowStockCount > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$lowStockCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: l10n?.parts ?? 'Parts',
        );
      case 2:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.shopping_cart),
          activeIcon: const Icon(Icons.shopping_cart),
          label: l10n?.orders ?? 'Orders',
        );
      case 3:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.business),
          activeIcon: const Icon(Icons.business),
          label: l10n?.departments ?? 'Departments',
        );
      case 4:
      default:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.inventory),
          activeIcon: const Icon(Icons.inventory),
          label: l10n?.products ?? 'Products',
        );
    }
  }

  /// Get current page title based on selected index
  String _getPageTitle(AppLocalizations? l10n) {
    if (l10n == null) return 'Baraka Parts';
    switch (_currentIndex) {
      case 0:
        return l10n.translate('analytics') ?? 'Analytics';
      case 1:
        return l10n.parts;
      case 2:
        return l10n.orders;
      case 3:
        return l10n.departments;
      case 4:
        return l10n.products;
      default:
        return 'Baraka Parts';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentUser = AuthStateService().currentUser;
    final isWorker = currentUser?.isWorker ?? false;
    final isCourier = currentUser?.isCourier ?? false;
    
    // Courierlar ham analytics, parts, va orders sahifalarini ko'ra oladi
    final visibleIndices = isCourier 
        ? [0, 1, 2]  // 0: Analytics, 1: Parts, 2: Orders
        : isWorker 
            ? [0, 1, 2]  // 0: Analytics, 1: Parts, 2: Orders
            : [0, 1, 2, 3, 4]; // Barcha sahifalar boshqalarga
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getPageTitle(l10n),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n?.settings ?? 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex >= visibleIndices.length ? 0 : _currentIndex,
        children: visibleIndices.map((i) => _pages[i]).toList(),
      ),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: _boxService.partsListenable,
        builder: (context, Box<PartModel> box, _) {
          // Optimize by caching the low stock count calculation
          final lowStockCount = _getLowStockCount();

          if (_currentIndex >= visibleIndices.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentIndex = 0;
                });
              }
            });
          }

          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) {
              // Optimize navigation to prevent unnecessary rebuilds
              if (_currentIndex != index) {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            items: visibleIndices
                .map((i) => _buildNavItem(i, l10n, lowStockCount))
                .toList(),
          );
        },
      ),
    );
  }
}

