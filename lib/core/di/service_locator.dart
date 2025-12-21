/// Service Locator / Dependency Injection
/// 
/// Centralized dependency injection for the application.
/// In production, consider using get_it or injectable package.

import '../../domain/repositories/part_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/department_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/repositories/log_repository.dart';
import '../../infrastructure/datasources/supabase_part_datasource.dart';
import '../../infrastructure/datasources/supabase_product_datasource.dart';
import '../../infrastructure/datasources/supabase_order_datasource.dart';
import '../../infrastructure/datasources/supabase_department_datasource.dart';
import '../../infrastructure/cache/hive_part_cache.dart';
import '../../infrastructure/cache/hive_product_cache.dart';
import '../../infrastructure/cache/hive_order_cache.dart';
import '../../infrastructure/cache/hive_department_cache.dart';
import '../../infrastructure/repositories/part_repository_impl.dart';
import '../../infrastructure/repositories/product_repository_impl.dart';
import '../../infrastructure/repositories/order_repository_impl.dart';
import '../../infrastructure/repositories/department_repository_impl.dart';
import '../../application/services/audit_service.dart';

class ServiceLocator {
  static ServiceLocator? _instance;
  static ServiceLocator get instance {
    _instance ??= ServiceLocator._();
    return _instance!;
  }
  
  ServiceLocator._();
  
  // Datasources
  late final SupabasePartDatasource _partDatasource = SupabasePartDatasource();
  late final SupabaseProductDatasource _productDatasource = SupabaseProductDatasource();
  late final SupabaseOrderDatasource _orderDatasource = SupabaseOrderDatasource();
  late final SupabaseDepartmentDatasource _departmentDatasource = SupabaseDepartmentDatasource();
  
  // Cache
  late final HivePartCache _partCache = HivePartCache();
  late final HiveProductCache _productCache = HiveProductCache();
  late final HiveOrderCache _orderCache = HiveOrderCache();
  late final HiveDepartmentCache _departmentCache = HiveDepartmentCache();
  
  // Repositories
  late final PartRepository _partRepository = PartRepositoryImpl(
    supabaseDatasource: _partDatasource,
    cache: _partCache,
  );
  
  late final ProductRepository _productRepository = ProductRepositoryImpl(
    supabaseDatasource: _productDatasource,
    cache: _productCache,
  );
  
  late final OrderRepository _orderRepository = OrderRepositoryImpl(
    supabaseDatasource: _orderDatasource,
    cache: _orderCache,
  );
  
  late final DepartmentRepository _departmentRepository = DepartmentRepositoryImpl(
    supabaseDatasource: _departmentDatasource,
    cache: _departmentCache,
  );
  // late final UserRepository _userRepository = UserRepositoryImpl(...);
  // late final LogRepository _logRepository = LogRepositoryImpl(...);
  
  // late final AuditService _auditService = AuditService(_logRepository);
  
  // Getters
  PartRepository get partRepository => _partRepository;
  ProductRepository get productRepository => _productRepository;
  OrderRepository get orderRepository => _orderRepository;
  DepartmentRepository get departmentRepository => _departmentRepository;
  // UserRepository get userRepository => _userRepository;
  // LogRepository get logRepository => _logRepository;
  // AuditService get auditService => _auditService;
  
  /// Initialize all services
  Future<void> init() async {
    await _partCache.init();
    await _productCache.init();
    await _orderCache.init();
    await _departmentCache.init();
  }
}

