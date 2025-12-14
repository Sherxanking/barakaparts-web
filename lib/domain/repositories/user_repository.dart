/// User repository interface - Domain layer
/// 
/// Defines the contract for user data operations.
/// 
/// STEP 1 CHANGE: Added signUp method for secure registration flow.

import '../entities/user.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

abstract class UserRepository {
  /// Get current authenticated user
  Future<Either<Failure, User?>> getCurrentUser();
  
  /// Get user by ID
  Future<Either<Failure, User?>> getUserById(String userId);
  
  /// Sign in with email and password
  /// WHY: Email/password login for all users
  Future<Either<Failure, User>> signInWithEmailAndPassword(String email, String password);
  
  /// Sign up new user with email and password
  /// WHY: Registration for Manager and Boss accounts
  /// Returns User if successful, or Failure if registration fails
  Future<Either<Failure, User>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    String role = 'worker', // Default role for normal registration
  });
  
  /// Sign out current user
  Future<Either<Failure, void>> signOut();
  
  /// Update user profile
  Future<Either<Failure, User>> updateUser(User user);

  /// Get all users (for admin panel)
  /// RBAC: Only managers and boss should call this
  Future<Either<Failure, List<User>>> getAllUsers();

  /// Update user role (for admin panel)
  /// RBAC: Only managers and boss can update roles
  Future<Either<Failure, User>> updateUserRole({
    required String userId,
    required String newRole,
  });

  /// Create user by admin (for admin panel)
  /// RBAC: Only managers and boss can create users
  Future<Either<Failure, User>> createUserByAdmin({
    required String email,
    required String password,
    required String name,
    required String role,
  });
}

