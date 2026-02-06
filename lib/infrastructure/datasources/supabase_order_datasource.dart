/// Supabase Order Datasource

import '../../domain/entities/order.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import 'supabase_client.dart';

class SupabaseOrderDatasource {
  final AppSupabaseClient _client = AppSupabaseClient.instance;
  
  String get _tableName => 'orders';
  
  Future<Either<Failure, List<Order>>> getAllOrders() async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);
      
      final orders = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(orders);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch orders: $e'));
    }
  }
  
  Future<Either<Failure, Order?>> getOrderById(String orderId) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .eq('id', orderId)
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      if (e.toString().contains('PGRST116')) {
        return Right(null);
      }
      return Left(ServerFailure('Failed to fetch order: $e'));
    }
  }
  
  Future<Either<Failure, List<Order>>> getOrdersByStatus(String status) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .eq('status', status)
          .order('created_at', ascending: false);
      
      final orders = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(orders);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch orders by status: $e'));
    }
  }
  
  Future<Either<Failure, List<Order>>> getOrdersByDepartment(String departmentId) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .eq('department_id', departmentId)
          .order('created_at', ascending: false);
      
      final orders = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(orders);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch orders by department: $e'));
    }
  }
  
  Future<Either<Failure, List<Order>>> searchOrders(String query) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .ilike('product_name', '%$query%')
          .order('created_at', ascending: false);
      
      final orders = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(orders);
    } catch (e) {
      return Left(ServerFailure('Failed to search orders: $e'));
    }
  }
  
  Future<Either<Failure, Order>> createOrder(Order order) async {
    try {
      final json = _mapToJson(order);
      final response = await _client.client
          .from(_tableName)
          .insert(json)
          .select()
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      return Left(ServerFailure('Failed to create order: $e'));
    }
  }
  
  Future<Either<Failure, Order>> updateOrder(Order order) async {
    try {
      final json = _mapToJson(order);
      json['updated_at'] = DateTime.now().toIso8601String();
      
      final response = await _client.client
          .from(_tableName)
          .update(json)
          .eq('id', order.id)
          .select()
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      return Left(ServerFailure('Failed to update order: $e'));
    }
  }
  
  Future<Either<Failure, Order>> approveOrder(String orderId, String approvedBy) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .update({
            'status': 'completed',
            'approved_by': approvedBy,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .select()
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      return Left(ServerFailure('Failed to approve order: $e'));
    }
  }
  
  Future<Either<Failure, Order>> rejectOrder(String orderId, String rejectedBy) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .update({
            'status': 'rejected',
            'approved_by': rejectedBy,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .select()
          .single();
      
      return Right(_mapFromJson(response));
    } catch (e) {
      return Left(ServerFailure('Failed to reject order: $e'));
    }
  }
  
  Future<Either<Failure, void>> deleteOrder(String orderId) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .delete()
          .eq('id', orderId)
          .select();
      
      // Check if any rows were deleted
      if (response.isEmpty) {
        return Left(ServerFailure('Order not found or you do not have permission to delete it'));
      }
      
      return Right(null);
    } catch (e) {
      // Check if it's a permission error
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission') || errorMessage.contains('policy') || errorMessage.contains('row-level security')) {
        return Left(ServerFailure('Sizda order o\'chirish huquqi yo\'q. Faqat Manager va Boss order o\'chira oladi.'));
      }
      return Left(ServerFailure('Failed to delete order: $e'));
    }
  }
  
  Future<Either<Failure, List<Order>>> getOrdersThisMonth() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      final response = await _client.client
          .from(_tableName)
          .select()
          .gte('created_at', startOfMonth.toIso8601String())
          .order('created_at', ascending: false);
      
      final orders = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right(orders);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch orders this month: $e'));
    }
  }
  
  Future<Either<Failure, int>> getProductionCountForMonth(DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 1).subtract(Duration(days: 1));
      
      final response = await _client.client
          .from(_tableName)
          .select('quantity')
          .eq('status', 'completed')
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String());
      
      final total = (response as List)
          .map((json) => json['quantity'] as int)
          .fold(0, (sum, qty) => sum + qty);
      
      return Right(total);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch production count: $e'));
    }
  }

  // Yangi qo'shilayotgan metodlar

  Future<Either<Failure, bool>> softDeleteOrder(String orderId, {String? reason}) async {
    try {
      // PostgreSQL funksiyasini chaqirish
      final response = await _client.client.rpc(
        'soft_delete_order',
        params: {
          'order_id': orderId,
          'reason': reason,
        },
      );
      
      // Response true/false bo'ladi
      return Right(response as bool);
    } catch (e) {
      return Left(ServerFailure('Failed to soft delete order: $e'));
    }
  }

  Future<Either<Failure, bool>> restoreOrder(String orderId) async {
    try {
      // PostgreSQL funksiyasini chaqirish
      final response = await _client.client.rpc(
        'restore_deleted_order',
        params: {
          'order_id': orderId,
        },
      );
      
      // Response true/false bo'ladi
      return Right(response as bool);
    } catch (e) {
      return Left(ServerFailure('Failed to restore order: $e'));
    }
  }

  Future<Either<Failure, bool>> permanentlyDeleteOrder(String orderId) async {
    try {
      // PostgreSQL funksiyasini chaqirish
      final response = await _client.client.rpc(
        'permanently_delete_order',
        params: {
          'order_id': orderId,
        },
      );
      
      // Response true/false bo'ladi
      return Right(response as bool);
    } catch (e) {
      return Left(ServerFailure('Failed to permanently delete order: $e'));
    }
  }

  Future<Either<Failure, List<Order>>> getDeletedOrders() async {
    try {
      // deleted_orders view'dan olish
      final response = await _client.client
          .from('deleted_orders')
          .select()
          .order('deleted_at', ascending: false);
      
      final orders = (response as List)
          .map((json) => _mapFromDeletedJson(json))
          .toList();
      
      return Right(orders);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch deleted orders: $e'));
    }
  }

  /// JSON dan Order entityga o'girish
  Order _mapFromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      completedQuantity: json['completed_quantity'] as int? ?? 0,
      departmentId: json['department_id'] as String,
      status: json['status'] as String,
      workerId: json['worker_id'] as String?,
      completedBy: json['completed_by'] as String?,
      createdBy: json['created_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      soldTo: json['sold_to'] as String?,
      notes: json['notes'] as String?,
      partsRequired: json['parts_required'] != null 
          ? Map<String, int>.from(json['parts_required'] as Map)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  /// Order entitydan JSON ga o'girish
  Map<String, dynamic> _mapToJson(Order order) {
    return {
      'id': order.id,
      'product_id': order.productId,
      'product_name': order.productName,
      'quantity': order.quantity,
      'completed_quantity': order.completedQuantity,
      'department_id': order.departmentId,
      'status': order.status,
      'worker_id': order.workerId,
      'completed_by': order.completedBy,
      'created_by': order.createdBy,
      'approved_by': order.approvedBy,
      'sold_to': order.soldTo,
      'notes': order.notes,
      'parts_required': order.partsRequired,
      'created_at': order.createdAt.toIso8601String(),
      'updated_at': order.updatedAt?.toIso8601String(),
      'completed_at': order.completedAt?.toIso8601String(),
    };
  }

  /// JSON dan Order entityga o'girish (deleted_orders view uchun)
  Order _mapFromDeletedJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      completedQuantity: json['completed_quantity'] as int? ?? 0,
      departmentId: json['department_id'] as String,
      status: json['status'] as String,
      workerId: json['worker_id'] as String?,
      completedBy: json['completed_by'] as String?,
      createdBy: json['created_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      soldTo: json['sold_to'] as String?,
      notes: json['notes'] as String?,
      partsRequired: json['parts_required'] != null 
          ? Map<String, int>.from(json['parts_required'] as Map)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  /// Real-time orders stream
  Stream<List<Order>> watchOrders() {
    return _client.client
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => _mapFromJson(json)).toList());
  }
}

