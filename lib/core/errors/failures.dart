/// Core error handling for the application
/// 
/// This file defines the base failure classes used throughout the app
/// following the Either pattern for functional error handling.

import 'package:equatable/equatable.dart';

/// Base class for all failures in the application
abstract class Failure extends Equatable {
  final String message;
  
  const Failure(this.message);
  
  @override
  List<Object> get props => [message];
}

/// Server-related failures (network, API errors)
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Cache-related failures (Hive, local storage)
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Permission/Authorization failures
class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Unknown/unexpected failures
class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

