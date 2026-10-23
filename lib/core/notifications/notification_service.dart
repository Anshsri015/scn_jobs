import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:scn_jobs/domain/entities/app_notification.dart';

class NotificationService {
  NotificationService(this._localNotifications);
  final FlutterLocalNotificationsPlugin _localNotifications;

  static const _channel = AndroidNotificationChannel(
    'application_status_channel',
    'Application Updates',
    description: 'Notified when a recruiter updates your application status.',
    importance: Importance.high,
  );

  /// Admin broadcasts (`POST /notifications`) delivered over the SSE
  /// stream. Separate channel so a worker can mute announcements in
  /// system settings without also muting application-status updates.
  static const _announcementsChannel = AndroidNotificationChannel(
    'announcements_channel',
    'Announcements',
    description: 'Announcements and updates from the SCN Jobs team.',
    importance: Importance.high,
  );

  /// Tapping an announcement opens the in-app notifications list.
  static const announcementTapRoute = '/notifications';

  Future<void> initialize({
    required void Function(String route) onNotificationTap,
  }) async {
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.createNotificationChannel(_announcementsChannel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onNotificationTap(payload);
      },
    );
  }

  /// Android 13+ needs the runtime POST_NOTIFICATIONS permission or
  /// `show()` silently does nothing. Called once after login (not at
  /// app launch) so the system dialog appears when it makes sense.
  /// No-op on older Android / if already granted.
  Future<void> requestPermission() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Pops a system notification for a live-streamed admin broadcast.
  Future<void> showAnnouncement(AppNotification notification) async {
    await _localNotifications.show(
      // Stable per notification id, and always a positive 31-bit int.
      notification.id.hashCode & 0x7fffffff,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _announcementsChannel.id,
          _announcementsChannel.name,
          channelDescription: _announcementsChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          // Long admin messages otherwise get cut to one line.
          styleInformation: BigTextStyleInformation(notification.body),
        ),
      ),
      payload: announcementTapRoute,
    );
  }

  /// Called on logout so a previous user's alerts don't linger in the
  /// notification shade on a shared device.
  Future<void> cancelAll() => _localNotifications.cancelAll();

// getToken(), _showForegroundNotification(), onMessage/onMessageOpenedApp,
// firebaseMessagingBackgroundHandler — sab hata do, FCM nahi hai abhi.
}
