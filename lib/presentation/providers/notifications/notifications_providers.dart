import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/network/dio_provider.dart';
import 'package:scn_jobs/core/notifications/notification_service.dart';
import 'package:scn_jobs/core/storage/isar_service.dart';
import 'package:scn_jobs/data/datasources/notification_local_datasource.dart';
import 'package:scn_jobs/data/datasources/notifications_remote_datasource.dart';
import 'package:scn_jobs/domain/entities/app_notification.dart';

final localNotificationsPluginProvider =
Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(localNotificationsPluginProvider));
});

final notificationLocalDataSourceProvider =
Provider<NotificationLocalDataSource>((ref) {
  return NotificationLocalDataSource(IsarService.instance);
});

final notificationsRemoteDataSourceProvider =
Provider<NotificationsRemoteDataSource>((ref) {
  return NotificationsRemoteDataSource(ref.watch(dioProvider));
});

/// Live list straight from Isar — re-emits on every insert / mark-read /
/// logout wipe, so neither the list screen nor the bell badge needs a
/// manual `ref.invalidate` (this was a one-shot `FutureProvider` before;
/// consumers use `.when(...)` either way, so they didn't need to change).
final notificationsListProvider = StreamProvider<List<AppNotification>>((
    ref,
    ) async* {
  final dataSource = ref.watch(notificationLocalDataSourceProvider);
  await for (final _ in dataSource.watchChanges()) {
    yield await dataSource.getAll();
  }
});

/// Drives the red dot on the home-screen bell.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsListProvider).asData?.value ??
      const <AppNotification>[];
  return list.where((n) => !n.isRead).length;
});