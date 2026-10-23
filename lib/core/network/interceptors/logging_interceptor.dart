import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:scn_jobs/core/utils/logger.dart';

/// Logs requests/responses/errors — active only in debug mode.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) {
    if (kDebugMode) {
      AppLogger.d('→ ${options.method} ${options.uri}');
      if (options.data != null) AppLogger.d('  body: ${options.data}');
    }
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response,
      ResponseInterceptorHandler handler,
      ) {
    if (kDebugMode) {
      AppLogger.d(
        '← ${response.statusCode} ${response.requestOptions.uri}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) {
    // WHY: some requests — like main.dart's Render warm-up ping to
    // `/`, which is EXPECTED to 404 and is silently ignored by its
    // own try/catch — have nothing useful to say here. Logging them
    // anyway prints a scary red ⛔ block on every single app start
    // for something that was never actually a problem. Callers opt
    // out per-request via `Options(extra: {'silentLog': true})`
    // rather than this interceptor guessing which failures "count".
    final silent = err.requestOptions.extra['silentLog'] == true;
    if (kDebugMode && !silent) {
      AppLogger.e(
        '✕ ${err.requestOptions.uri} — ${err.message}',
      );
      final data = err.response?.data;
      if (data != null) {
        AppLogger.e('  server response: $data');
      }
    }
    handler.next(err);
  }

}
