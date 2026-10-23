import 'package:scn_jobs/domain/entities/app_notification.dart';

/// Wire shape of one notification — identical for an item inside
/// `GET /notifications` -> `data[]` and for the `data:` payload of an SSE
/// `event: notification` frame:
///
/// ```json
/// { "id": "...", "title": "...", "message": "...", "audience": "ALL",
///   "createdById": "...", "createdAt": "2026-09-21T10:15:00.000Z" }
/// ```
///
/// `audience` / `createdById` are deliberately not modelled — the backend
/// already filters by role, so the app never needs them.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final title = json['title']?.toString();
    final message = json['message']?.toString();
    if (id == null || id.isEmpty || title == null || message == null) {
      throw const FormatException(
        'Notification payload is missing id / title / message',
      );
    }
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      // Server sends UTC (`...Z`); convert so the list shows the
      // worker's local date, not the UTC one.
      createdAt:
      DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;

  /// `message` -> `body` and `createdAt` -> `receivedAt` so the existing
  /// Isar schema (`NotificationLocalModel`) and its generated `.g.dart`
  /// keep working untouched — no build_runner run needed.
  AppNotification toEntity() => AppNotification(
    id: id,
    title: title,
    body: message,
    receivedAt: createdAt,
  );
}
