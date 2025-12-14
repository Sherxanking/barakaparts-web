/// Either type for functional error handling
/// 
/// This is a simplified Either implementation for the app.
/// For production, consider using the dartz package.

/// Either type that represents a value of type L (Left/Error) or R (Right/Success)
sealed class Either<L, R> {
  const Either();
  
  /// Returns true if this is a Right value
  bool get isRight => this is Right<L, R>;
  
  /// Returns true if this is a Left value
  bool get isLeft => this is Left<L, R>;
  
  /// Gets the Right value, throws if Left
  R get right => (this as Right<L, R>).value;
  
  /// Gets the Left value, throws if Right
  L get left => (this as Left<L, R>).value;
  
  /// Maps the Right value
  Either<L, B> map<B>(B Function(R) f) {
    if (this is Right<L, R>) {
      return Right(f((this as Right<L, R>).value));
    }
    return Left((this as Left<L, R>).value);
  }
  
  /// Maps the Left value
  Either<B, R> mapLeft<B>(B Function(L) f) {
    if (this is Left<L, R>) {
      return Left(f((this as Left<L, R>).value));
    }
    return Right((this as Right<L, R>).value);
  }
  
  /// Folds both sides
  T fold<T>(T Function(L) onLeft, T Function(R) onRight) {
    if (this is Left<L, R>) {
      return onLeft((this as Left<L, R>).value);
    }
    return onRight((this as Right<L, R>).value);
  }
  
  /// Flat map (bind)
  Either<L, B> flatMap<B>(Either<L, B> Function(R) f) {
    if (this is Right<L, R>) {
      return f((this as Right<L, R>).value);
    }
    return Left((this as Left<L, R>).value);
  }
}

/// Left side of Either (typically represents error/failure)
class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);
}

/// Right side of Either (typically represents success)
class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);
}

