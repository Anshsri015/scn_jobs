import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scn_jobs/core/env/app_config.dart';
import 'package:scn_jobs/core/network/interceptors/auth_interceptor.dart';
import 'package:scn_jobs/core/network/interceptors/error_interceptor.dart';
import 'package:scn_jobs/core/network/interceptors/logging_interceptor.dart';
import 'package:scn_jobs/core/storage/secure_storage_service.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
/// Bumped whenever a logged-in request gets a 401. `AppRouter` listens to
/// this and logs the user out (see `_GoRouterRefreshNotifier`).
final ValueNotifier<int> sessionExpiredNotifier = ValueNotifier<int>(0);

final cookieJarProvider = Provider<CookieJar>((ref) {
  return CookieJar();
});
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  final secureStorageService = ref.watch(secureStorageServiceProvider);
  final cookieJar = ref.watch(cookieJarProvider);
  // Order matters: auth → cookies → logging → retry → error mapping
  dio.interceptors.addAll([
    AuthInterceptor(secureStorageService),
    CookieManager(cookieJar),
    LoggingInterceptor(),
    RetryInterceptor(
      dio: dio,
      retries: 2,
      retryDelays: const [
        Duration(seconds: 1),
        Duration(seconds: 2),
      ],
      // Requests can opt out via `Options(extra: {'noRetry': true})` —
      // e.g. the splash-screen `/auth/me` check, which already uses a
      // short 6s timeout and needs to fail fast rather than stack 2
      // more retries on top (worst case ~48s total otherwise), which
      // was why the app appeared to "hang" before falling back to
      // onboarding.
      retryEvaluator: (error, attempt) async {
        if (error.requestOptions.extra['noRetry'] == true) return false;
        return error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError;
      },
    ),
    ErrorInterceptor(
      onUnauthorized: () async => sessionExpiredNotifier.value++,
    ),
  ]);
  return dio;
});
