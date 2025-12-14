/// User Repository Implementation
/// 
/// Handles user authentication and profile management.
/// 
/// STEP 1 CHANGE: Added signUp, checkEmailVerification, and resendEmailVerification methods.

import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../datasources/supabase_user_datasource.dart';

class UserRepositoryImpl implements UserRepository {
  final SupabaseUserDatasource _datasource;
  
  UserRepositoryImpl({
    required SupabaseUserDatasource datasource,
  }) : _datasource = datasource;

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    return await _datasource.getCurrentUser();
  }

  @override
  Future<Either<Failure, User?>> getUserById(String userId) async {
    return await _datasource.getUserById(userId);
  }

  @override
  Future<Either<Failure, User>> signInWithEmailAndPassword(String email, String password) async {
    return await _datasource.signInWithEmailAndPassword(email, password);
  }

  @override
  Future<Either<Failure, User>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    String role = 'worker',
  }) async {
    return await _datasource.signUpWithEmailAndPassword(
      email: email,
      password: password,
      name: name,
      role: role,
    );
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    return await _datasource.signOut();
  }

  @override
  Future<Either<Failure, User>> updateUser(User user) async {
    return await _datasource.updateUser(user);
  }

  @override
  Future<Either<Failure, List<User>>> getAllUsers() async {
    return await _datasource.getAllUsers();
  }

  @override
  Future<Either<Failure, User>> updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    return await _datasource.updateUserRole(
      userId: userId,
      newRole: newRole,
    );
  }

  @override
  Future<Either<Failure, User>> createUserByAdmin({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    return await _datasource.createUserByAdmin(
      email: email,
      password: password,
      name: name,
      role: role,
    );
  }
}


