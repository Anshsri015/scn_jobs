import 'package:scn_jobs/core/error/api_failure.dart';

/// Sealed result type for network calls — either Success<T> or Error.
sealed class ApiResult<T> {
  const ApiResult();

  factory ApiResult.success(T data) = ApiSuccess<T>;
  factory ApiResult.error(ApiFailure failure) = ApiError<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(ApiFailure failure) error,
  }) {
    final self = this;
    if (self is ApiSuccess<T>) return success(self.data);
    if (self is ApiError<T>) return error(self.failure);
    throw StateError('Unknown ApiResult subtype');
  }
}

class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data);
  final T data;
}

class ApiError<T> extends ApiResult<T> {
  const ApiError(this.failure);
  final ApiFailure failure;
}
