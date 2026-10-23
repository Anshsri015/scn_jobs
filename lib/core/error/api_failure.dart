/// App-level failure shown to the UI/ViewModel layer.
///
/// Repositories catch raw data-layer exceptions (`ServerException`,
/// `NetworkException`, etc. from `exceptions.dart`) and translate them
/// into one of these subtypes before they reach a Riverpod provider or
/// widget. Sealed so every consumer's `switch` must be exhaustive.
sealed class ApiFailure {
  const ApiFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends ApiFailure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class ServerFailure extends ApiFailure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;
}

class UnauthorizedFailure extends ApiFailure {
  const UnauthorizedFailure([super.message = 'Session expired']);
}

class ValidationFailure extends ApiFailure {
  const ValidationFailure(super.message, {this.fieldErrors});

  final Map<String, String>? fieldErrors;
}

class CacheFailure extends ApiFailure {
  const CacheFailure([super.message = 'Could not read or write local data.']);
}

class UnknownFailure extends ApiFailure {
  const UnknownFailure([super.message = 'Unexpected error occurred.']);
}
