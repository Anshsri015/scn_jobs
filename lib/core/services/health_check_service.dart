import 'package:dio/dio.dart';

import 'package:scn_jobs/core/env/app_config.dart';
import 'package:scn_jobs/core/utils/logger.dart';

/// Pings `/api/health` and tracks consecutive failures. A DEDICATED Dio
/// instance (not `dioProvider`'s, which carries auth/retry/error
/// interceptors) — a health check must succeed or fail on its own
/// terms, not get auto-retried 2x by `RetryInterceptor` or auth-gated
/// by `AuthInterceptor` before this service even sees the result.
class HealthCheckService {
  HealthCheckService() : _dio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));

  final Dio _dio;
  int _consecutiveFailures = 0;

  /// Matches the plan's "3 failures" threshold for showing
  /// `MaintenanceScreen`.
  static const int failureThreshold = 3;

  bool get isUnhealthy => _consecutiveFailures >= failureThreshold;

  Future<bool> check() async {
    try {
      await _dio.get<void>(
        '/health',
        options: Options(sendTimeout: const Duration(seconds: 5)),
      );
      _consecutiveFailures = 0;
      return true;
    } catch (e) {
      _consecutiveFailures++;
      AppLogger.w(
        'Health check failed ($_consecutiveFailures/$failureThreshold): $e',
      );
      return false;
    }
  }

  void reset() => _consecutiveFailures = 0;
}
