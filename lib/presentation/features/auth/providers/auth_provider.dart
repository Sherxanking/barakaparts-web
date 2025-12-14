/// Auth Provider - Riverpod
/// 
/// Authentication state management uchun Riverpod provider

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../domain/entities/user.dart';
import '../../../../domain/repositories/user_repository.dart';
import '../../../../infrastructure/datasources/supabase_user_datasource.dart';
import '../../../../infrastructure/repositories/user_repository_impl.dart';

part 'auth_provider.g.dart';

/// Repository provider
@riverpod
UserRepository userRepository(UserRepositoryRef ref) {
  return UserRepositoryImpl(
    datasource: SupabaseUserDatasource(),
  );
}

/// Current user provider (Stream)
@riverpod
Stream<User?> currentUserStream(CurrentUserStreamRef ref) {
  final repository = ref.watch(userRepositoryProvider);
  // TODO: watchAuthState() metodini qo'shish kerak
  // Hozircha getCurrentUser() ishlatamiz
  return Stream.periodic(
    const Duration(seconds: 1),
    (_) async {
      final result = await repository.getCurrentUser();
      return result.fold(
        (failure) => null,
        (user) => user,
      );
    },
  ).asyncMap((future) => future);
}

/// Auth state provider (loading, error, user)
@riverpod
class AuthState extends _$AuthState {
  @override
  Future<User?> build() async {
    final repository = ref.watch(userRepositoryProvider);
    final result = await repository.getCurrentUser();
    return result.fold(
      (failure) => null,
      (user) => user,
    );
  }
  
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    final repository = ref.read(userRepositoryProvider);
    final result = await repository.signInWithEmailAndPassword(email, password);
    
    state = result.fold(
      (failure) => AsyncValue.error(failure, StackTrace.current),
      (user) => AsyncValue.data(user),
    );
  }
  
  Future<void> signOut() async {
    final repository = ref.read(userRepositoryProvider);
    final result = await repository.signOut();
    result.fold(
      (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        state = const AsyncValue.data(null);
      },
    );
  }
}




