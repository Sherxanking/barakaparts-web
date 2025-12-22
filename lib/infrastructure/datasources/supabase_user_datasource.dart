/// Supabase User Datasource
/// 
/// ⚠️ MUHIM: Faqat ANON key ishlatiladi!
/// Authentication Supabase Auth orqali amalga oshiriladi.

// All imports must be at the top before any declarations
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user.dart' as domain;
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../core/constants/app_constants.dart';
import 'supabase_client.dart';

// Type alias after all imports
// SOLUTION A: Use type alias to avoid conflict between Supabase User and domain.User
// Supabase User type (from auth) - use this for Supabase authentication users
typedef SupabaseUser = User;

class SupabaseUserDatasource {
  final AppSupabaseClient _client = AppSupabaseClient.instance;
  
  String get _tableName => 'users';
  
  /// Sign in with email and password
  /// WHY: Email/password login for Manager and Boss test accounts
  /// ⚠️ MUHIM: Bu frontend orqali, faqat ANON key bilan!
  Future<Either<Failure, domain.User>> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Supabase initialize qilinganini tekshirish
      if (!AppSupabaseClient.isInitialized) {
        return Left<Failure, domain.User>(AuthFailure('Supabase is not initialized. Please restart the app.'));
      }
      
      // Validate inputs
      if (email.trim().isEmpty) {
        return Left<Failure, domain.User>(AuthFailure('Please enter your email address.'));
      }
      if (password.isEmpty) {
        return Left<Failure, domain.User>(AuthFailure('Please enter your password.'));
      }
      
      debugPrint('🔐 Attempting login for: ${email.trim()}');
      
      final response = await _client.client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      // Check if user is null (should not happen, but handle gracefully)
      if (response.user == null) {
        debugPrint('❌ Login failed: User is null after signInWithPassword');
        return Left<Failure, domain.User>(AuthFailure('Login failed. Please check your email and password, then try again.'));
      }
      
      // STEP 1: Check email verification status
      // WHY: Test accounts (manager@test.com, boss@test.com) bypass email verification
      // Note: If email confirmation is disabled in Supabase settings, this check will pass
      final isTestAccount = _getRoleForTestAccount(email.trim()) != null;
      final isEmailVerified = response.user!.emailConfirmedAt != null;
      
      if (!isEmailVerified && !isTestAccount) {
        debugPrint('⚠️ Email not verified for: ${email.trim()}');
        // Return special failure that UI can handle to show verification prompt
        return Left<Failure, domain.User>(AuthFailure(
          'EMAIL_NOT_VERIFIED: Please verify your email before signing in. '
          'Check your inbox for the verification link.'
        ));
      }
      
      // Test accounts bypass email verification
      if (isTestAccount && !isEmailVerified) {
        debugPrint('⚠️ Test account email not verified, but allowing login: ${email.trim()}');
      }
      
      debugPrint('✅ Email verified, fetching user profile...');
      
      // FIX: Optimize login - check user profile immediately (no retry needed for login)
      // Get user data from users table
      final userResult = await getUserById(response.user!.id);
      return await userResult.fold(
        (failure) async {
          debugPrint('⚠️ User profile not found in users table, attempting auto-create...');
          // Determine role for test accounts
          final role = _getRoleForTestAccount(email.trim());
          // Agar users jadvalida topilmasa, avtomatik yaratishga harakat qilamiz
          return await _autoCreateUser(
            userId: response.user!.id,
            email: email.trim(),
            name: response.user!.userMetadata?['name'] as String? ?? email.split('@')[0],
            role: role,
          );
        },
        (user) async {
          if (user == null) {
            debugPrint('⚠️ User profile is null, attempting auto-create...');
            // Determine role for test accounts
            final role = _getRoleForTestAccount(email.trim());
            // User topilmadi - avtomatik yaratishga harakat qilamiz
            return await _autoCreateUser(
              userId: response.user!.id,
              email: email.trim(),
              name: response.user!.userMetadata?['name'] as String? ?? email.split('@')[0],
              role: role,
            );
          }
          // For test accounts, ensure role is correct (in case it was changed)
          final testRole = _getRoleForTestAccount(email.trim());
          if (testRole != null && user.role != testRole) {
            debugPrint('⚠️ Test account role mismatch, updating role from ${user.role} to $testRole');
            // Update role for test account
            final updateResult = await updateUserRole(userId: user.id, newRole: testRole);
            return updateResult.fold(
              (failure) => Right<Failure, domain.User>(user), // Return original user if update fails
              (updatedUser) => Right<Failure, domain.User>(updatedUser),
            );
          }
          debugPrint('✅ Login successful: ${user.name} (${user.role})');
          return Right<Failure, domain.User>(user);
        },
      );
    } on AuthException catch (e) {
      // Handle Supabase Auth-specific errors
      debugPrint('❌ AuthException: ${e.message}');
      final errorMessage = e.message.toLowerCase();
      
      if (errorMessage.contains('invalid login credentials') || 
          errorMessage.contains('invalid login') ||
          errorMessage.contains('wrong password')) {
        return Left<Failure, domain.User>(AuthFailure('Invalid email or password. Please check and try again.'));
      } else if (errorMessage.contains('email not confirmed') || 
                 errorMessage.contains('email_not_confirmed')) {
        return Left<Failure, domain.User>(AuthFailure(
          'EMAIL_NOT_VERIFIED: Email not verified. Please check your inbox and verify your email before signing in.'
        ));
      } else if (errorMessage.contains('user not found')) {
        return Left<Failure, domain.User>(AuthFailure('No account found with this email. Please register first.'));
      } else if (errorMessage.contains('too many requests')) {
        return Left<Failure, domain.User>(AuthFailure('Too many login attempts. Please wait a few minutes and try again.'));
      }
      return Left<Failure, domain.User>(AuthFailure('Login failed: ${e.message}'));
    } catch (e) {
      // Handle other errors (network, PostgrestException, etc.)
      debugPrint('❌ Login error: $e');
      final errorMessage = e.toString().toLowerCase();
      
      if (errorMessage.contains('postgresexception') || 
          errorMessage.contains('postgrest')) {
        return Left<Failure, domain.User>(AuthFailure('Database error. Please try again later.'));
      } else if (errorMessage.contains('failed host lookup') || 
                 errorMessage.contains('socketexception') ||
                 errorMessage.contains('no address associated') ||
                 errorMessage.contains('network') || 
                 errorMessage.contains('connection') ||
                 errorMessage.contains('timeout')) {
        return Left<Failure, domain.User>(AuthFailure(
          'No internet connection. Please check your network and try again.'
        ));
      } else if (errorMessage.contains('authretryablefetchexception')) {
        return Left<Failure, domain.User>(AuthFailure(
          'Unable to connect to server. Please check your internet connection and try again.'
        ));
      }
      return Left<Failure, domain.User>(AuthFailure('Login failed: ${e.toString()}'));
    }
  }
  
  // Google OAuth removed - only email/password authentication is supported


  /// Sign out current user
  Future<Either<Failure, void>> signOut() async {
    try {
      await _client.client.auth.signOut();
      return Right<Failure, void>(null);
    } catch (e) {
      return Left<Failure, void>(AuthFailure('Failed to sign out: $e'));
    }
  }
  
  /// Get current authenticated user
  /// FIX: Safe profile fetch with auto-create fallback
  /// WHY: Prevents "Failed to load user profile" crash
  Future<Either<Failure, domain.User?>> getCurrentUser() async {
    try {
      final authUser = _client.currentUser;
      if (authUser == null) {
        return Right<Failure, domain.User?>(null);
      }
      
      // Try to get user profile
      final userResult = await getUserById(authUser.id);
      
      return await userResult.fold(
        (failure) async {
          // Profile fetch failed - try to auto-create
          debugPrint('⚠️ Profile not found, attempting auto-create...');
          return await _autoCreateUser(
            userId: authUser.id,
            email: authUser.email ?? '',
            name: authUser.userMetadata?['name'] as String? ?? 
                  authUser.userMetadata?['full_name'] as String? ??
                  authUser.email?.split('@')[0] ?? 'User',
            role: null, // Will be determined by _autoCreateUser
          );
        },
        (user) async {
          if (user == null) {
            // Profile is null - try to auto-create
            debugPrint('⚠️ Profile is null, attempting auto-create...');
            return await _autoCreateUser(
              userId: authUser.id,
              email: authUser.email ?? '',
              name: authUser.userMetadata?['name'] as String? ?? 
                    authUser.userMetadata?['full_name'] as String? ??
                    authUser.email?.split('@')[0] ?? 'User',
              role: null,
            );
          }
          return Right<Failure, domain.User?>(user);
        },
      );
    } catch (e) {
      debugPrint('❌ Error in getCurrentUser: $e');
      return Left<Failure, domain.User?>(AuthFailure('Failed to get current user: $e'));
    }
  }
  
  /// Get user by ID from users table
  /// FIX: Safe fetch with maybeSingle instead of single
  /// WHY: Prevents crash if user doesn't exist
  Future<Either<Failure, domain.User?>> getUserById(String userId) async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (response == null) {
        return Right<Failure, domain.User?>(null); // Not found
      }
      
      return Right<Failure, domain.User?>(_mapFromJson(response));
    } catch (e) {
      debugPrint('❌ Error in getUserById: $e');
      if (e.toString().contains('PGRST116') || e.toString().contains('null')) {
        return Right<Failure, domain.User?>(null); // Not found
      }
      return Left<Failure, domain.User?>(ServerFailure('Failed to fetch user: $e'));
    }
  }
  
  /// Get all users (for admin panel)
  /// WHY: Admin panel needs to list all users with their roles
  /// RBAC: Only managers and boss should call this
  Future<Either<Failure, List<domain.User>>> getAllUsers() async {
    try {
      final response = await _client.client
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);
      
      final users = (response as List)
          .map((json) => _mapFromJson(json))
          .toList();
      
      return Right<Failure, List<domain.User>>(users);
    } catch (e) {
      debugPrint('❌ Failed to fetch users: $e');
      return Left<Failure, List<domain.User>>(ServerFailure('Failed to fetch users: $e'));
    }
  }

  /// Update user role
  /// WHY: Admin panel needs to update user roles
  /// RBAC: Only managers and boss can update roles
  /// NOTE: Updates both users table and auth.users metadata
  Future<Either<Failure, domain.User>> updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    try {
      // Validate role
      if (!['worker', 'manager', 'boss'].contains(newRole)) {
        return Left<Failure, domain.User>(ValidationFailure('Invalid role: $newRole'));
      }

      // Update role in users table
      final response = await _client.client
          .from(_tableName)
          .update({'role': newRole})
          .eq('id', userId)
          .select()
          .single();

      // Note: Updating auth.users metadata requires service role key
      // For now, we only update the users table. The trigger or a separate admin function
      // should sync the role to auth.users.raw_user_meta_data if needed.

      debugPrint('✅ User role updated: $userId -> $newRole');
      return Right<Failure, domain.User>(_mapFromJson(response));
    } catch (e) {
      debugPrint('❌ Failed to update user role: $e');
      return Left<Failure, domain.User>(ServerFailure('Failed to update user role: $e'));
    }
  }

  /// Create user by admin (for admin panel)
  /// WHY: Admin panel needs to create users with specific roles
  /// RBAC: Only managers and boss can create users
  Future<Either<Failure, domain.User>> createUserByAdmin({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      // Validate role
      if (!['worker', 'manager', 'boss'].contains(role)) {
        return Left<Failure, domain.User>(ValidationFailure('Invalid role: $role'));
      }

      // Create auth user
      final authResponse = await _client.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': name.trim(),
          'role': role,
        },
      );

      if (authResponse.user == null) {
        return Left<Failure, domain.User>(AuthFailure('Failed to create user'));
      }

      // Wait for trigger to create profile (trigger should use role from metadata)
      // FIX: Optimize - check immediately, then retry only if needed
      domain.User? createdUser;
      const maxRetries = 3; // Reduced from 5 to 3
      const retryDelay = Duration(milliseconds: 300); // Reduced from 500ms
      
      for (int i = 0; i < maxRetries; i++) {
        if (i > 0) {
          await Future.delayed(retryDelay);
        }
        
        final userResult = await getUserById(authResponse.user!.id);
        userResult.fold(
          (failure) {
            debugPrint('⏳ Waiting for trigger... (attempt ${i + 1}/$maxRetries)');
          },
          (user) {
            if (user != null) {
              createdUser = user;
              debugPrint('✅ User profile found: ${user.name} (${user.role})');
            }
          },
        );
        
        if (createdUser != null) {
          // Check if role matches, if not update it
          if (createdUser!.role != role) {
            debugPrint('⚠️ Role mismatch: expected $role, got ${createdUser!.role}, updating...');
            final updateResult = await updateUserRole(
              userId: authResponse.user!.id,
              newRole: role,
            );
            return updateResult;
          }
          return Right<Failure, domain.User>(createdUser!);
        }
      }
      
      // If trigger didn't create profile, create it manually
      if (createdUser == null) {
        debugPrint('⚠️ Trigger did not create profile, creating manually...');
        return await _autoCreateUser(
          userId: authResponse.user!.id,
          email: email.trim(),
          name: name.trim(),
          role: role,
        );
      }
      
      return Right<Failure, domain.User>(createdUser!);
    } on AuthException catch (e) {
      debugPrint('❌ AuthException creating user: ${e.message}');
      if (e.message.contains('already registered') || e.message.contains('already exists')) {
        return Left<Failure, domain.User>(AuthFailure('User with this email already exists.'));
      }
      return Left<Failure, domain.User>(AuthFailure('Failed to create user: ${e.message}'));
    } catch (e) {
      debugPrint('❌ Failed to create user by admin: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      debugPrint('   Full error: ${e.toString()}');
      
      final errorStr = e.toString().toLowerCase();
      
      // Check for specific database errors
      if (errorStr.contains('permission denied') || 
          errorStr.contains('row-level security') ||
          errorStr.contains('new row violates row-level security')) {
        return Left<Failure, domain.User>(ServerFailure(
          'Database error: Permission denied. The trigger may not have proper RLS bypass. '
          'Please run migration 012_fix_trigger_rls_bypass.sql in Supabase Dashboard → SQL Editor.'
        ));
      } else if (errorStr.contains('duplicate key') || 
                 errorStr.contains('already exists') ||
                 errorStr.contains('unique constraint')) {
        return Left<Failure, domain.User>(AuthFailure('User with this email already exists.'));
      } else if (errorStr.contains('violates foreign key') ||
                 errorStr.contains('foreign key constraint')) {
        return Left<Failure, domain.User>(ServerFailure('Database error: Invalid reference. Please check your data.'));
      } else if (errorStr.contains('postgresexception') || 
                 errorStr.contains('postgrest') ||
                 errorStr.contains('pgrst')) {
        return Left<Failure, domain.User>(ServerFailure(
          'Database error creating new user. Please check:\n'
          '1. Trigger handle_new_user() exists and has SECURITY DEFINER\n'
          '2. RLS policies allow INSERT for authenticated users\n'
          '3. Run migration 012_fix_trigger_rls_bypass.sql'
        ));
      }
      
      return Left<Failure, domain.User>(ServerFailure('Failed to create user: $e'));
    }
  }

  /// Update user profile
  Future<Either<Failure, domain.User>> updateUser(domain.User user) async {
    try {
      // First check if user exists
      final userCheck = await getUserById(user.id);
      return userCheck.fold(
        (failure) {
          debugPrint('❌ User not found, cannot update: ${user.id}');
          return Left<Failure, domain.User>(ServerFailure('User not found. Please try logging in again.'));
        },
        (existingUser) async {
          if (existingUser == null) {
            debugPrint('⚠️ User not found in database, creating...');
            // User doesn't exist, create it
            if (user.email == null || user.email!.isEmpty) {
              return Left<Failure, domain.User>(ValidationFailure('User email is required but not provided.'));
            }
            return await _autoCreateUser(
              userId: user.id,
              email: user.email!,
              name: user.name,
              role: user.role ?? 'worker',
            );
          }
          
          // User exists, update it
          final json = _mapToJson(user);
          json['updated_at'] = DateTime.now().toIso8601String();
          
          final response = await _client.client
              .from(_tableName)
              .update(json)
              .eq('id', user.id)
              .select()
              .single();
          
          debugPrint('✅ User updated successfully: ${user.email}');
          return Right<Failure, domain.User>(_mapFromJson(response));
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to update user: $e');
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('null') || errorStr.contains('not found') || errorStr.contains('pgrst116')) {
        // User doesn't exist, try to create it
        debugPrint('⚠️ User not found during update, attempting to create...');
        if (user.email == null || user.email!.isEmpty) {
          return Left<Failure, domain.User>(ValidationFailure('User email is required but not provided.'));
        }
        return await _autoCreateUser(
          userId: user.id,
          email: user.email!,
          name: user.name,
          role: user.role ?? 'worker',
        );
      }
      
      return Left<Failure, domain.User>(ServerFailure('Failed to update user: $e'));
    }
  }
  
  /// Sign up new user with email and password
  /// WHY: Registration for Manager and Boss accounts
  /// The trigger `handle_new_user()` creates the profile in public.users after auth.signUp()
  /// ⚠️ MUHIM: Bu frontend orqali, lekin backend API orqali tavsiya etiladi!
  Future<Either<Failure, domain.User>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    String role = 'worker',
  }) async {
    try {
      if (!AppSupabaseClient.isInitialized) {
        return Left<Failure, domain.User>(AuthFailure('Supabase is not initialized. Please restart the app.'));
      }
      
      // Validate inputs
      if (email.trim().isEmpty) {
        return Left<Failure, domain.User>(AuthFailure('Please enter your email address.'));
      }
      if (password.isEmpty) {
        return Left<Failure, domain.User>(AuthFailure('Please enter a password.'));
      }
      if (password.length < 6) {
        return Left<Failure, domain.User>(AuthFailure('Password must be at least 6 characters long.'));
      }
      if (name.trim().isEmpty) {
        return Left<Failure, domain.User>(AuthFailure('Please enter your name.'));
      }
      
      // Additional email validation before sending to Supabase
      final trimmedEmail = email.trim().toLowerCase(); // Normalize email
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(trimmedEmail)) {
        return Left<Failure, domain.User>(AuthFailure(
          'Invalid email address format. Please use a valid email format like: name@example.com'
        ));
      }
      
      // Check for common invalid patterns
      if (trimmedEmail.contains('..') || 
          trimmedEmail.startsWith('.') || 
          trimmedEmail.endsWith('.') ||
          trimmedEmail.contains('@.') ||
          trimmedEmail.contains('.@')) {
        return Left<Failure, domain.User>(AuthFailure(
          'Invalid email address format. Email cannot contain consecutive dots or start/end with dots.'
        ));
      }
      
      debugPrint('📝 Registering user: $trimmedEmail');
      
      // 1. Supabase Auth orqali user yaratish
      // The trigger will automatically create profile in public.users table
      // NOTE: Supabase may reject certain email domains (like test.com) - this is a Supabase configuration issue
      final authResponse = await _client.client.auth.signUp(
        email: trimmedEmail,
        password: password,
        data: {
          'name': name.trim(),
          'role': role,
        },
      );
      
      // Check if user is null (should not happen, but handle gracefully)
      if (authResponse.user == null) {
        debugPrint('❌ Registration failed: User is null after signUp');
        return Left<Failure, domain.User>(AuthFailure('Registration failed. Please try again.'));
      }
      
      debugPrint('✅ Auth user created, checking for profile...');
      
      // 2. Wait for trigger to create profile in public.users table
      // FIX: Optimize - check immediately, then retry only if needed (faster login)
      // WHY: The trigger `handle_new_user()` automatically creates the profile after auth.signUp()
      const maxRetries = 3; // Reduced from 5 to 3 for faster login
      const retryDelay = Duration(milliseconds: 300); // Reduced from 500ms
      domain.User? createdUser;
      
      for (int i = 0; i < maxRetries; i++) {
        // Only delay after first attempt
        if (i > 0) {
          await Future.delayed(retryDelay);
        }
        
        final userResult = await getUserById(authResponse.user!.id);
        userResult.fold(
          (failure) {
            // Profile not found yet, continue retrying
            if (i < maxRetries - 1) {
              debugPrint('⏳ Waiting for trigger... (attempt ${i + 1}/$maxRetries)');
            }
          },
          (user) {
            if (user != null) {
              createdUser = user;
              debugPrint('✅ User profile created by trigger: ${user.name} (${user.email ?? trimmedEmail}) - role: ${user.role}');
            }
          },
        );
        
        if (createdUser != null) {
          break;
        }
      }
      
      // 3. Return the created user profile or create manually if trigger failed
      if (createdUser != null) {
        // Check if role matches, if not update it
        if (createdUser!.role != role) {
          debugPrint('⚠️ Role mismatch: expected $role, got ${createdUser!.role}, updating...');
          final updateResult = await updateUserRole(
            userId: authResponse.user!.id,
            newRole: role,
          );
          return updateResult;
        }
        return Right<Failure, domain.User>(createdUser!);
      } else {
        // Trigger didn't create profile - create it manually
        debugPrint('⚠️ Trigger did not create profile, creating manually...');
        return await _autoCreateUser(
          userId: authResponse.user!.id,
          email: email.trim(),
          name: name.trim(),
          role: role,
        );
      }
    } on AuthException catch (e) {
      // Handle Supabase Auth-specific errors
      debugPrint('❌ AuthException during registration: ${e.message}');
      final errorMessage = e.message.toLowerCase();
      
      if (errorMessage.contains('user already registered') || 
          errorMessage.contains('already registered') ||
          errorMessage.contains('email already exists') ||
          errorMessage.contains('already exists')) {
        return Left<Failure, domain.User>(AuthFailure('This email is already registered. Please sign in instead.'));
      } else if (errorMessage.contains('password') && 
                 (errorMessage.contains('weak') || errorMessage.contains('short') || errorMessage.contains('minimum'))) {
        return Left<Failure, domain.User>(AuthFailure('Password is too weak. Use at least 6 characters.'));
      } else if (errorMessage.contains('invalid email') || 
                 errorMessage.contains('malformed') ||
                 (errorMessage.contains('email address') && errorMessage.contains('invalid'))) {
        // More helpful error message for invalid email
        // NOTE: Supabase may reject certain email domains (like test.com) due to configuration
        return Left<Failure, domain.User>(AuthFailure(
          'Invalid email address. Supabase may not accept this email domain.\n\n'
          'Please try:\n'
          '• Using a common email provider (gmail.com, yahoo.com, outlook.com)\n'
          '• Checking if the email format is correct\n'
          '• Contacting admin if using a custom domain\n\n'
          'Note: Some test domains (like test.com) may be blocked by Supabase security settings.'
        ));
      } else if (errorMessage.contains('signup disabled')) {
        return Left<Failure, domain.User>(AuthFailure('Registration is currently disabled. Please contact support.'));
      }
      return Left<Failure, domain.User>(AuthFailure('Registration failed: ${e.message}'));
    } catch (e) {
      // Handle other errors (network, PostgrestException, etc.)
      debugPrint('❌ Registration error: $e');
      final errorMessage = e.toString().toLowerCase();
      
      if (errorMessage.contains('postgresexception') || 
          errorMessage.contains('postgrest')) {
        return Left<Failure, domain.User>(AuthFailure('Database error during registration. Please try again later.'));
      } else if (errorMessage.contains('failed host lookup') || 
                 errorMessage.contains('socketexception') ||
                 errorMessage.contains('network') || 
                 errorMessage.contains('connection') ||
                 errorMessage.contains('timeout')) {
        return Left<Failure, domain.User>(AuthFailure(
          'No internet connection. Please check your network and try again.'
        ));
      }
      return Left<Failure, domain.User>(AuthFailure('Registration failed: ${e.toString()}'));
    }
  }

  /// Check if current user's email is verified (STEP 1: Email verification check)
  Future<Either<Failure, bool>> checkEmailVerification() async {
    try {
      if (!AppSupabaseClient.isInitialized) {
        return Left<Failure, bool>(AuthFailure('Supabase is not initialized.'));
      }
      
      final currentUser = _client.currentUser;
      if (currentUser == null) {
        return Left<Failure, bool>(AuthFailure('No user is currently signed in.'));
      }
      
      // Check if email is confirmed
      final isVerified = currentUser.emailConfirmedAt != null;
      return Right<Failure, bool>(isVerified);
    } catch (e) {
      return Left<Failure, bool>(AuthFailure('Failed to check email verification: $e'));
    }
  }
  
  /// Resend email verification (STEP 1: Email verification resend)
  /// FIX: Use OtpType.signup instead of OtpType.email for signup verification
  /// WHY: Supabase requires OtpType.signup for signup email verification, not OtpType.email
  /// [email] - REQUIRED email address for signup verification
  Future<Either<Failure, void>> resendEmailVerification({String? email}) async {
    try {
      if (!AppSupabaseClient.isInitialized) {
        return Left<Failure, void>(AuthFailure('Supabase is not initialized.'));
      }
      
      // FIX: Email is REQUIRED for OtpType.signup - never allow null
      String? emailToUse = email;
      
      // If email not provided, try to get from current user
      if (emailToUse == null || emailToUse.isEmpty) {
        final currentUser = _client.currentUser;
        if (currentUser != null && currentUser.email != null && currentUser.email!.isNotEmpty) {
          emailToUse = currentUser.email;
        }
      }
      
      // FIX: Validate email is NOT null or empty before calling resend
      if (emailToUse == null || emailToUse.isEmpty || !emailToUse.contains('@')) {
        return Left<Failure, void>(AuthFailure(
          'Email address is required to resend verification. Please provide a valid email address.'
        ));
      }
      
      // FIX: Use OtpType.signup for signup email verification (not OtpType.email)
      // WHY: Supabase requires OtpType.signup for signup verification emails
      await _client.client.auth.resend(
        type: OtpType.signup,
        email: emailToUse.trim(),
      );
      
      debugPrint('✅ Email verification resent to: $emailToUse');
      return Right<Failure, void>(null);
    } on AuthException catch (e) {
      debugPrint('❌ AuthException during resend: ${e.message}');
      return Left<Failure, void>(AuthFailure('Failed to resend email verification: ${e.message}'));
    } catch (e) {
      debugPrint('❌ Error resending email verification: $e');
      return Left<Failure, void>(AuthFailure('Failed to resend email verification: ${e.toString()}'));
    }
  }
  
  /// Map JSON to User entity
  /// FIX: Handle missing fields gracefully
  domain.User _mapFromJson(Map<String, dynamic> json) {
    return domain.User(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      role: (json['role'] as String?) ?? 'worker', // Default to worker if null
      departmentId: json['department_id'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(), // Default to now if null
    );
  }
  
  /// Map User entity to JSON
  Map<String, dynamic> _mapToJson(domain.User user) {
    return {
      'id': user.id,
      'name': user.name,
      'phone': user.phone,
      'email': user.email,
      'role': user.role,
      'created_at': user.createdAt.toIso8601String(),
    };
  }
  
  /// Avtomatik user yaratish (users jadvalida topilmasa)
  /// Get role for test accounts
  /// WHY: Test mode - special accounts have elevated roles
  /// Manager: manager@test.com → role 'manager'
  /// Boss: boss@test.com → role 'boss'
  /// All others → null (use default 'manager' - TEMPORARY)
  String? _getRoleForTestAccount(String email) {
    final emailLower = email.toLowerCase();
    if (emailLower == 'manager@test.com') {
      return 'manager';
    } else if (emailLower == 'boss@test.com') {
      return 'boss';
    }
    return null; // Use default role
  }

  Future<Either<Failure, domain.User>> _autoCreateUser({
    required String userId,
    required String email,
    required String name,
    String? role,
  }) async {
    try {
      // Determine role: test account role or default 'worker'
      final userRole = role ?? _getRoleForTestAccount(email) ?? 'worker';
      
      debugPrint('🔄 Attempting to auto-create user: $email (role: $userRole)');
      
      // FIX: Use upsert (INSERT ... ON CONFLICT) to handle existing users
      // NOTE: department_id removed - not in new schema
      final userJson = {
        'id': userId,
        'name': name,
        'email': email,
        'role': userRole,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Try to insert, if exists then update
      final response = await _client.client
          .from(_tableName)
          .upsert(userJson, onConflict: 'id')
          .select()
          .single();
      
      // Map response to User entity
      final createdUser = _mapFromJson(response);
      
      debugPrint('✅ User avtomatik yaratildi/yangilandi: ${createdUser.name} (${createdUser.email}) - role: ${createdUser.role}');
      
      return Right<Failure, domain.User>(createdUser);
    } catch (e) {
      debugPrint('❌ Auto-create error: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      
      // If user already exists, try to fetch it
      if (e.toString().contains('duplicate') || 
          e.toString().contains('unique') ||
          e.toString().contains('already exists')) {
        debugPrint('⚠️ User may already exist, attempting to fetch...');
        final userResult = await getUserById(userId);
        return userResult.fold(
          (failure) {
            // User doesn't exist and can't be created - show helpful error
            final finalRole = role ?? _getRoleForTestAccount(email) ?? 'worker';
            return Left<Failure, domain.User>(AuthFailure(
              'User avtomatik yaratilmadi. Users jadvaliga qo\'shing.\n\n'
              'SQL Editor da quyidagini bajaring:\n\n'
              'INSERT INTO users (id, name, email, role)\n'
              'VALUES (\'$userId\', \'$name\', \'$email\', \'$finalRole\')\n'
              'ON CONFLICT (id) DO NOTHING;\n\n'
              'User ID: $userId\n'
              'Email: $email\n'
              'Role: $finalRole'
            ));
          },
          (user) {
            if (user != null) {
              debugPrint('✅ User found after auto-create attempt: ${user.name}');
              return Right<Failure, domain.User>(user);
            }
            final finalRole = role ?? _getRoleForTestAccount(email) ?? 'worker';
            return Left<Failure, domain.User>(AuthFailure(
              'User avtomatik yaratilmadi. Users jadvaliga qo\'shing.\n\n'
              'SQL Editor da quyidagini bajaring:\n\n'
              'INSERT INTO users (id, name, email, role)\n'
              'VALUES (\'$userId\', \'$name\', \'$email\', \'$finalRole\')\n'
              'ON CONFLICT (id) DO NOTHING;\n\n'
              'User ID: $userId\n'
              'Email: $email'
            ));
          },
        );
      }
      
      // Check for RLS/permission errors
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission denied') || 
          errorStr.contains('row-level security') ||
          errorStr.contains('new row violates')) {
        final finalRole = role ?? _getRoleForTestAccount(email) ?? 'worker';
        return Left<Failure, domain.User>(ServerFailure(
          'Database permission error. RLS policies not configured correctly.\n\n'
          'Please run SIMPLE_FIX.sql in Supabase SQL Editor:\n\n'
          '1. Go to Supabase Dashboard → SQL Editor\n'
          '2. Open SIMPLE_FIX.sql file\n'
          '3. Copy and paste ALL SQL code\n'
          '4. Click RUN button\n'
          '5. Restart the app and try login again'
        ));
      }
      
      // Generic error - show SQL to fix
      final finalRole = role ?? _getRoleForTestAccount(email) ?? 'worker';
      return Left<Failure, domain.User>(AuthFailure(
        'User avtomatik yaratilmadi. Users jadvaliga qo\'shing.\n\n'
        'SQL Editor da quyidagini bajaring:\n\n'
        'INSERT INTO users (id, name, email, role)\n'
        'VALUES (\'$userId\', \'$name\', \'$email\', \'$finalRole\')\n'
        'ON CONFLICT (id) DO NOTHING;\n\n'
        'User ID: $userId\n'
        'Email: $email\n'
        'Error: ${e.toString()}'
      ));
    }
  }
}

