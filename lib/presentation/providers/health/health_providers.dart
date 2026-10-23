import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/services/health_check_service.dart';

final healthCheckServiceProvider = Provider<HealthCheckService>((ref) {
  return HealthCheckService();
});

/// Polled every 30s from `app.dart` (not from every screen individually
/// — one timer, one source of truth for "is the backend up"). `false`
/// means healthy/unknown; only flips `true` after 3 consecutive
/// failures (see `HealthCheckService.failureThreshold`), and flips back
/// the moment a check succeeds.
class BackendHealthNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    _startPolling();
    return false;
  }

  void _startPolling() {
    final service = ref.read(healthCheckServiceProvider);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await service.check();
      state = service.isUnhealthy;
    });
  }

  /// Called from `MaintenanceScreen`'s Retry button — checks
  /// immediately instead of waiting for the next 30s tick.
  Future<void> checkNow() async {
    final service = ref.read(healthCheckServiceProvider);
    await service.check();
    state = service.isUnhealthy;
  }
}

final backendHealthyProvider = NotifierProvider<BackendHealthNotifier, bool>(
  BackendHealthNotifier.new,
);
