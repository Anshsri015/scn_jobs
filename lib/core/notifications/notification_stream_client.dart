import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'package:scn_jobs/core/env/app_config.dart';
import 'package:scn_jobs/core/utils/logger.dart';

/// Minimal Server-Sent-Events client for `GET /notifications/stream`.
///
/// Calls [onEvent] once per complete SSE frame (`event:` + `data:`).
/// Keep-alive comment lines (`: ping`) are swallowed here.
///
/// Reconnects by itself (4s, 8s, 16s ... capped at 30s after failures,
/// 2s after a clean drop) until [stop] is called; [onConnected] fires on
/// every successful (re)connection so the caller can re-fetch history
/// for whatever was missed in the gap.
///
/// WHY NOT `flutter_client_sse` / THE APP'S SHARED `dioProvider`:
/// - The stream URL carries `?token=<jwt>`. The shared Dio has a
///   `LoggingInterceptor` that would print that URL. This client owns a
///   bare Dio with NO interceptors, and never logs the URL or the raw
///   exception (Dio exception text can include the URI) — only the
///   error type and HTTP status.
/// - The shared Dio has `receiveTimeout: 15s` + a retry interceptor; the
///   server only pings every 25s, so a normal quiet stream would be
///   killed and retried. Here `receiveTimeout` is off and a separate
///   idle watchdog ([_idleTimeout]) covers half-open sockets instead.
class NotificationStreamClient {
  NotificationStreamClient({
    required Future<String?> Function() tokenProvider,
    required void Function(String event, String data) onEvent,
    void Function()? onConnected,
    Dio? dio,
  })  : _tokenProvider = tokenProvider,
        _onEvent = onEvent,
        _onConnected = onConnected,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.baseUrl,
                // Generous: Render free tier cold-starts in 10-40s.
                connectTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 15),
                // Zero = no timeout. The idle watchdog below handles
                // dead connections instead.
                receiveTimeout: Duration.zero,
              ),
            );

  final Future<String?> Function() _tokenProvider;
  final void Function(String event, String data) _onEvent;
  final void Function()? _onConnected;
  final Dio _dio;

  /// Server pings every 25s. Two missed pings + slack => the connection
  /// is dead (network switched, socket half-open) — reconnect.
  static const Duration _idleTimeout = Duration(seconds: 70);

  bool _running = false;
  int _generation = 0;
  void Function()? _abortCurrent;

  bool get isRunning => _running;

  /// Idempotent — a second call while already running does nothing.
  void start() {
    if (_running) return;
    _running = true;
    final generation = ++_generation;
    unawaited(_loop(generation));
  }

  /// Closes the connection and stops reconnecting. Safe to call anytime.
  void stop() {
    if (!_running) return;
    _terminate();
  }

  void _terminate() {
    _running = false;
    _generation++; // invalidates any loop that is mid-delay / mid-connect
    _abortCurrent?.call();
  }

  Future<void> _loop(int generation) async {
    var failures = 0;

    while (generation == _generation) {
      var opened = false;
      try {
        final token = await _tokenProvider();
        if (generation != _generation) return;
        if (token == null || token.isEmpty) {
          AppLogger.w('SSE: no session token, not connecting');
          _terminate();
          return;
        }
        opened = await _connectOnce(token, generation);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (e.type == DioExceptionType.cancel) {
          // stop() or idle-abort — the generation check below decides.
        } else if (status == 401) {
          // Token rejected — retrying with the same token can't succeed.
          // Normal API calls surface the expired session; a fresh login
          // calls start() again.
          AppLogger.w('SSE: 401 from stream, stopping');
          _terminate();
          return;
        } else {
          AppLogger.w('SSE: connect failed (${e.type.name}, status $status)');
        }
      } catch (e) {
        AppLogger.w('SSE: connect failed (${e.runtimeType})');
      }

      if (generation != _generation) return;

      failures = opened ? 0 : failures + 1;
      final backoffSeconds = opened ? 2 : min(30, 2 << failures); // 4,8,16,30..
      await Future<void>.delayed(Duration(seconds: backoffSeconds));
    }
  }

  /// Opens the stream and blocks until it ends. Returns `true` if the
  /// connection was actually established (headers OK), so the caller can
  /// reset its backoff. Throws [DioException] if it could not connect.
  Future<bool> _connectOnce(String token, int generation) async {
    final cancel = CancelToken();

    final response = await _dio.get<ResponseBody>(
      '/notifications/stream',
      queryParameters: {'token': token},
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      ),
    );

    if (generation != _generation) {
      cancel.cancel('stopped');
      return false;
    }

    // Render's "waking up" interstitial can come back as a plain 200
    // HTML page — that is not a stream, don't treat it as connected.
    final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';
    if (!contentType.contains('text/event-stream')) {
      cancel.cancel('not an event stream');
      throw StateError('unexpected content-type');
    }

    final body = response.data!;
    _onConnected?.call();

    final done = Completer<void>();
    Timer? idle;

    void finish() {
      idle?.cancel();
      if (!done.isCompleted) done.complete();
    }

    void resetIdle() {
      idle?.cancel();
      idle = Timer(_idleTimeout, () {
        AppLogger.w('SSE: silent for ${_idleTimeout.inSeconds}s, reconnecting');
        finish();
      });
    }

    _abortCurrent = finish;
    resetIdle();

    // Per-frame state (SSE spec: a frame ends at a blank line).
    var eventName = 'message';
    final dataLines = <String>[];

    void dispatch() {
      if (dataLines.isEmpty) {
        eventName = 'message';
        return;
      }
      final name = eventName;
      final payload = dataLines.join('\n');
      dataLines.clear();
      eventName = 'message';
      try {
        _onEvent(name, payload);
      } catch (e) {
        // A bad handler must never kill the stream.
        AppLogger.w('SSE: event handler threw (${e.runtimeType})');
      }
    }

    void onLine(String line) {
      if (line.isEmpty) {
        dispatch();
        return;
      }
      if (line.startsWith(':')) return; // comment / ": ping" keep-alive

      final colon = line.indexOf(':');
      final field = colon == -1 ? line : line.substring(0, colon);
      var value = colon == -1 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);

      switch (field) {
        case 'event':
          eventName = value;
        case 'data':
          dataLines.add(value);
        default:
          break; // `id:` / `retry:` are not used by this backend
      }
    }

    final sub = body.stream
        .map((chunk) {
      resetIdle(); // any bytes at all (incl. pings) = still alive
      return chunk;
    })
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      onLine,
      onError: (Object e) {
        AppLogger.w('SSE: stream error (${e.runtimeType})');
        finish();
      },
      onDone: finish,
      cancelOnError: true,
    );

    try {
      await done.future;
    } finally {
      _abortCurrent = null;
      idle?.cancel();
      await sub.cancel();
      cancel.cancel('closed');
    }
    return true;
  }
}
