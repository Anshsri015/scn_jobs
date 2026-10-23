/// Exceptions thrown by the **data layer** (remote/local data sources).
///
/// These are raw, low-level signals — a Dio 500, a cache miss, a JSON
/// parse failure. Repositories catch these and translate them into
/// `ApiFailure`s (see `api_failure.dart`) before they ever reach a
/// Riverpod provider or a widget. Screens and ViewModels must never
/// catch these directly.
class ServerException implements Exception {
  const ServerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ServerException($statusCode): $message';
}

class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

class UnauthorizedException implements Exception {
  const UnauthorizedException([this.message = 'Session expired']);

  final String message;

  @override
  String toString() => 'UnauthorizedException: $message';
}

class CacheException implements Exception {
  const CacheException(this.message);

  final String message;

  @override
  String toString() => 'CacheException: $message';
}

class ValidationException implements Exception {
  const ValidationException(this.message, {this.fieldErrors});

  final String message;
  final Map<String, String>? fieldErrors;

  @override
  String toString() => 'ValidationException: $message';
}
