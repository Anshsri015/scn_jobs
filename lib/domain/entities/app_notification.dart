/// [applicationId] drives deep-linking (tapping a notification about a
/// status change opens that application's detail screen) — null for
/// notifications that don't relate to a specific application (e.g. a
/// future "new jobs matching your profile" type).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.applicationId,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final String? applicationId;
  final bool isRead;
}
