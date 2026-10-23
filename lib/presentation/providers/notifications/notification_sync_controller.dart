import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/network/dio_provider.dart';
import 'package:scn_jobs/core/notifications/notification_stream_client.dart';
import 'package:scn_jobs/core/utils/logger.dart';
import 'package:scn_jobs/data/models/notification_model.dart';
import 'package:scn_jobs/domain/entities/user.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';
import 'package:scn_jobs/presentation/providers/notifications/notifications_providers.dart';
import 'package:scn_jobs/presentation/providers/settings/settings_providers.dart';

/// Owns the whole "notifications are live" lifecycle in one place:
///
/// - signed in            -> open SSE stream + fetch history
/// - signed out           -> close stream, clear shade
/// - app paused           -> close stream (PDF: keep it open only while
///                           foregrounded; Android kills the socket anyway)
/// - app resumed          -> reopen stream + re-fetch history so nothing
///                           posted during the gap is missed
/// - stream (re)connected -> re-fetch history (same reason)
///
/// Started simply by being watched once from `ScnJobsApp`.
class NotificationSyncController extends Notifier<void> {
  NotificationStreamClient? _client;

  String? _userId;
  Future<bool>? _inFlightRefresh;
  DateTime? _lastRefreshAt;

  @override
  void build() {
    final client = NotificationStreamClient(
      tokenProvider: () => ref.read(secureStorageServiceProvider).getAccessToken(),
      onEvent: _onStreamEvent,
      onConnected: _onStreamConnected,
    );
    _client = client;

    final observer = _LifecycleObserver(_onLifecycleChanged);
    WidgetsBinding.instance.addObserver(observer);

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(observer);
      client.stop();
    });

    ref.listen<AsyncValue<User?>>(
      authStateProvider,
          (previous, next) {
        // Loading = mid-refresh; error = transient session-check hiccup
        // (see `RouteGuards.authGuard`). Neither means "signed out" —
        // keep whatever state we have.
        if (next.isLoading || next.hasError) return;
        final user = next.value;
        if (user == null) {
          _onSignedOut();
        } else {
          _onSignedIn(user.id);
        }
      },
      fireImmediately: true,
    );
  }

  // ── Auth ────────────────────────────────────────────────────────────

  void _onSignedIn(String userId) {
    final client = _client!;
    if (_userId == userId && client.isRunning) return;

    _userId = userId;
    // Ask once the user is actually inside the app, not at cold launch.
    unawaited(_requestPermissionSafely());
    client.start();
    unawaited(refresh());
  }

  void _onSignedOut() {
    if (_userId == null && !(_client?.isRunning ?? false)) return;
    _userId = null;
    _client?.stop();
    unawaited(ref.read(notificationServiceProvider).cancelAll());
  }

  Future<void> _requestPermissionSafely() async {
    try {
      await ref.read(notificationServiceProvider).requestPermission();
    } catch (e) {
      AppLogger.w('Notification permission request failed (${e.runtimeType})');
    }
  }

  // ── App lifecycle ───────────────────────────────────────────────────

  void _onLifecycleChanged(AppLifecycleState state) {
    if (_userId == null) return;
    switch (state) {
      case AppLifecycleState.paused:
        _client?.stop();
      case AppLifecycleState.resumed:
        _client?.start(); // no-op if still running
        unawaited(refresh());
      default:
      // `inactive` fires for permission dialogs / notification shade
      // pull-downs — not worth dropping the connection for.
        break;
    }
  }

  // ── Stream events ───────────────────────────────────────────────────

  void _onStreamConnected() {
    // A (re)connect after a gap may have missed events; history covers
    // it. Skip if we literally just fetched (first connect right after
    // sign-in).
    final last = _lastRefreshAt;
    if (last != null && DateTime.now().difference(last).inSeconds < 3) return;
    unawaited(refresh());
  }

  void _onStreamEvent(String event, String data) {
    if (event != 'notification') return;
    unawaited(_handleNotificationEvent(data));
  }

  Future<void> _handleNotificationEvent(String data) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) return;

      final notification = NotificationModel.fromJson(json).toEntity();

      final isNew = await ref
          .read(notificationLocalDataSourceProvider)
          .saveIfAbsent(notification);
      if (!isNew || _userId != userId) return;

      // Always stored + badged; only the system pop-up respects the
      // user's "notifications enabled" preference.
      final enabled =
      await ref.read(appPreferencesServiceProvider).getNotificationsEnabled();
      if (enabled) {
        await ref.read(notificationServiceProvider).showAnnouncement(notification);
      }
    } catch (e, st) {
      AppLogger.e('Failed to handle live notification', e, st);
    }
  }

  // ── History ─────────────────────────────────────────────────────────

  /// `GET /notifications` -> merge into Isar. Returns `false` on failure
  /// (also used by pull-to-refresh so the screen can say so). Concurrent
  /// callers (resume + reconnect + pull-to-refresh) share one request.
  Future<bool> refresh() {
    if (_userId == null) return Future.value(false);
    return _inFlightRefresh ??= _doRefresh().whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  Future<bool> _doRefresh() async {
    final userId = _userId;
    try {
      final models =
      await ref.read(notificationsRemoteDataSourceProvider).fetchHistory();

      // Logged out (or switched account) while the request was in
      // flight — Isar was just wiped; writing now would leak the
      // previous user's notifications into the next session.
      if (_userId != userId) return false;

      await ref
          .read(notificationLocalDataSourceProvider)
          .mergeHistory(models.map((m) => m.toEntity()).toList());
      _lastRefreshAt = DateTime.now();
      return true;
    } catch (e) {
      AppLogger.w('Notification history sync failed (${e.runtimeType})');
      return false;
    }
  }
}

final notificationSyncControllerProvider =
NotifierProvider<NotificationSyncController, void>(
  NotificationSyncController.new,
);

class _LifecycleObserver with WidgetsBindingObserver {
  _LifecycleObserver(this._onChanged);

  final void Function(AppLifecycleState state) _onChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _onChanged(state);
}