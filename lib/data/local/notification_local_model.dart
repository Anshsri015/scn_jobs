import 'package:isar/isar.dart';

part 'notification_local_model.g.dart';

/// Lives in `lib/data/local/` deliberately — `build.yaml` scopes
/// `isar_generator` to only this folder (see build.yaml's comment),
/// so this is the first file that folder's existence was for. Any
/// future Isar collection (job cache, etc.) belongs here too.
@collection
class NotificationLocalModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String notificationId;

  late String title;
  late String body;
  late DateTime receivedAt;
  String? applicationId;
  bool isRead = false;
}
