// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userRepositoryHash() => r'38f24d91009672951b2bedcd56e873af7277a64e';

/// Repository provider
///
/// Copied from [userRepository].
@ProviderFor(userRepository)
final userRepositoryProvider = AutoDisposeProvider<UserRepository>.internal(
  userRepository,
  name: r'userRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef UserRepositoryRef = AutoDisposeProviderRef<UserRepository>;
String _$currentUserStreamHash() => r'5443acc8fcc281eb25db9e44fc7e0d1122aa2192';

/// Current user provider (Stream)
///
/// Copied from [currentUserStream].
@ProviderFor(currentUserStream)
final currentUserStreamProvider = AutoDisposeStreamProvider<User?>.internal(
  currentUserStream,
  name: r'currentUserStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentUserStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentUserStreamRef = AutoDisposeStreamProviderRef<User?>;
String _$authStateHash() => r'4d8deff486e9681937d861dea1b1e0eb856f19eb';

/// Auth state provider (loading, error, user)
///
/// Copied from [AuthState].
@ProviderFor(AuthState)
final authStateProvider =
    AutoDisposeAsyncNotifierProvider<AuthState, User?>.internal(
  AuthState.new,
  name: r'authStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AuthState = AutoDisposeAsyncNotifier<User?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
