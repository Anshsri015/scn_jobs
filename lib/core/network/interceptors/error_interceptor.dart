import 'package:dio/dio.dart';
import 'package:scn_jobs/core/error/api_failure.dart';

/// Converts raw DioExceptions into app-level ApiFailure subtypes.
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor({this.onUnauthorized});

  /// Called when a logged-in session gets a 401 (token expired, or the
  /// account was deleted/deactivated). The owner clears the session and
  /// the router sends the user to /login.
  final Future<void> Function()? onUnauthorized;

  @override
  void onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) {
    final failure = _mapToApiFailure(err);
    // Only for requests that actually carried a token. `/auth/*` calls
    // (login, me, ...) are skipped: login has no session yet, and
    // `/auth/me` 401 is already handled by `currentUser()`.
    if (failure is UnauthorizedFailure &&
        err.requestOptions.headers['Authorization'] != null &&
        !err.requestOptions.path.contains('/auth/')) {
      onUnauthorized?.call();
    }
    handler.next(
      err.copyWith(error: failure),
    );
  }

  ApiFailure _mapToApiFailure(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure('Connection timed out. Please try again.');

      case DioExceptionType.connectionError:
        return const NetworkFailure();

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        if (statusCode == 401) {
          return const UnauthorizedFailure();
        }
        // Doc-confirmed (device log, 12 Sep): this backend returns
        // validation-style failures (e.g. "Email already registered")
        // as plain 400s, NOT 422 — `POST /auth/worker/register`'s own
        // "invalid request" example uses the same `{message, errors:
        // [...]}` body shape the doc shows for every endpoint, and in
        // practice it comes back with status 400. Treating only 422
        // as a validation error meant 400s (the common case here)
        // always fell through to the generic ServerFailure branch
        // below, silently losing the field-error detail callers need
        // (e.g. RegisterScreen detecting an "already registered"
        // resubmit).
        if (statusCode == 422 || statusCode == 400) {
          return ValidationFailure(
            _extractServerMessage(err.response?.data) ??
                'Please fix the highlighted fields.',
            fieldErrors: _extractFieldErrors(err.response?.data),
          );
        }
        final message = _extractServerMessage(err.response?.data) ??
            'Something went wrong (code $statusCode).';
        return ServerFailure(message, statusCode: statusCode);

      case DioExceptionType.cancel:
        return const UnknownFailure('Request was cancelled.');

      default:
        return const UnknownFailure();
    }
  }

  String? _extractServerMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final direct = data['message'] as String? ?? data['error'] as String?;
      if (direct != null) return direct;
      // Doc-confirmed shape for several endpoints (e.g. both
      // forgot-password APIs) has NO top-level `message` at all —
      // only `{ success: false, errors: [{ message: "..." }] }`.
      // Without this fallback, every failure from those endpoints
      // silently lost its real message (e.g. "No account found with
      // this email", "Invalid or expired OTP") and fell through to
      // the generic "Something went wrong" / "Please fix the
      // highlighted fields." text instead.
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map && first['message'] != null) {
          return first['message'].toString();
        }
      }
    }
    return null;
  }

  /// Handles both shapes seen from this backend: `errors` as a
  /// `{field: message}` map, AND — the shape actually documented
  /// (`{ "message": ..., "field": ... }` items) and observed in
  /// practice, e.g. `POST /auth/worker/register`'s "Email already
  /// registered" response — `errors` as a LIST of objects, each with
  /// a `message` and an optional `field`. The old map-only version
  /// silently returned `null` for every real error from this API,
  /// since none of them actually use the map shape.
  Map<String, String>? _extractFieldErrors(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final errors = data['errors'];
    if (errors is Map) {
      return errors.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    if (errors is List) {
      final result = <String, String>{};
      for (var i = 0; i < errors.length; i++) {
        final entry = errors[i];
        if (entry is Map) {
          final message = entry['message']?.toString() ?? '';
          // Not every error item names a `field` (e.g. "Email already
          // registered" doesn't) — fall back to a positional key so
          // the message is never silently dropped.
          final field = entry['field']?.toString() ?? 'error_$i';
          result[field] = message;
        }
      }
      return result.isEmpty ? null : result;
    }
    return null;
  }
}
