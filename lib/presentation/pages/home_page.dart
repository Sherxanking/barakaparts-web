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
import '../../l10n/app_localizations.dart';
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

  @override
  void initState() {
    super.initState();
    // Har bir sahifa uchun navigator key yaratish
    _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
    
    // Sahifalarni yaratish
    _pages = [
      OrdersPage(key: _navigatorKeys[0]),
      DepartmentsPage(key: _navigatorKeys[1]),
      ProductsPage(key: _navigatorKeys[2]),
      PartsPage(key: _navigatorKeys[3]),
      SettingsPage(key: _navigatorKeys[4]),
    ];
  }

  /// Kam qolgan qismlarni olish
  int _getLowStockCount() {
    try {
      final partsBox = _boxService.partsBox;
      return partsBox.values.where((part) => part.quantity < part.minQuantity).length;
    } catch (e) {
      return 0;
    }
  }

  /// Get current page title based on selected index
  String _getPageTitle(AppLocalizations? l10n) {
    if (l10n == null) return 'Baraka Parts';
    switch (_currentIndex) {
      case 0:
        return l10n.orders;
      case 1:
        return l10n.departments;
      case 2:
        return l10n.products;
      case 3:
        return l10n.parts;
      case 4:
        return l10n.settings ?? 'Settings';
      default:
        return 'Baraka Parts';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: _boxService.partsListenable,
        builder: (context, Box<PartModel> box, _) {
          final lowStockCount = _getLowStockCount();
          
          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.shopping_cart),
                activeIcon: const Icon(Icons.shopping_cart),
                label: l10n?.orders ?? 'Orders',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.business),
                activeIcon: const Icon(Icons.business),
                label: l10n?.departments ?? 'Departments',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.inventory),
                activeIcon: const Icon(Icons.inventory),
                label: l10n?.products ?? 'Products',
              ),
              BottomNavigationBarItem(
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
                            lowStockCount > 9 ? '9+' : '$lowStockCount',
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
                            lowStockCount > 9 ? '9+' : '$lowStockCount',
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
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings),
                activeIcon: const Icon(Icons.settings),
                label: l10n?.settings ?? 'Settings',
              ),
            ],
          );
        },
      ),
    );
  }
}

