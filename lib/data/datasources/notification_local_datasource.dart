import 'package:isar/isar.dart';
import 'package:scn_jobs/core/storage/isar_service.dart';
import 'package:scn_jobs/data/local/notification_local_model.dart';
import 'package:scn_jobs/domain/entities/app_notification.dart';

class NotificationLocalDataSource {
  NotificationLocalDataSource(this._isarService);

  final IsarService _isarService;

  /// Upserts by `notificationId`. NOTE: because the index is
  /// `unique + replace`, this OVERWRITES an existing row — including its
  /// `isRead` flag. Use [saveIfAbsent] / [mergeHistory] for anything
  /// coming from the server; keep this only for callers that really
  /// mean "replace".
  Future<void> save(AppNotification notification) async {
    final isar = _isarService.isar;
    await isar.writeTxn(() => isar.notificationLocalModels.put(_toModel(notification)));
  }

  /// Stores [notification] only if its id isn't already present.
  /// Returns `true` if it was new — the caller uses that to decide
  /// whether to pop a system notification (an SSE event that history
  /// already delivered must not alert twice).
  Future<bool> saveIfAbsent(AppNotification notification) async {
    final isar = _isarService.isar;
    return isar.writeTxn(() => _insertIfMissing(isar, notification));
  }

  /// Merges a `GET /notifications` result into the local store.
  /// Existing rows are left completely untouched — server notifications
  /// are immutable, and this is what keeps a row's local `isRead=true`
  /// from being reset to unread on every history refetch (which is what
  /// a plain `put` would do). Returns how many rows were new.
  Future<int> mergeHistory(List<AppNotification> items) async {
    final isar = _isarService.isar;
    return isar.writeTxn(() async {
      var inserted = 0;
      for (final item in items) {
        if (await _insertIfMissing(isar, item)) inserted++;
      }
      return inserted;
    });
  }

  Future<List<AppNotification>> getAll() async {
    final isar = _isarService.isar;

    final models = await isar.notificationLocalModels
        .where()
        .sortByReceivedAtDesc()
        .findAll();

    return models.map(_toEntity).toList();
  }

  /// Emits (immediately, then on every insert / update / clear) — lets
  /// the list screen and the bell badge stay live without manual
  /// `ref.invalidate` calls.
  Stream<void> watchChanges() {
    return _isarService.isar.notificationLocalModels
        .watchLazy(fireImmediately: true);
  }

  Future<void> markRead(String notificationId) async {
    final isar = _isarService.isar;

    final model = await isar.notificationLocalModels
        .filter()
        .notificationIdEqualTo(notificationId)
        .findFirst();

    if (model == null) return;

    model.isRead = true;

    await isar.writeTxn(() => isar.notificationLocalModels.put(model));
  }

  Future<void> markAllRead() async {
    final isar = _isarService.isar;

    await isar.writeTxn(() async {
      final unread = await isar.notificationLocalModels
          .filter()
          .isReadEqualTo(false)
          .findAll();
      if (unread.isEmpty) return;
      for (final model in unread) {
        model.isRead = true;
      }
      await isar.notificationLocalModels.putAll(unread);
    });
  }

  /// Must be called inside a write transaction.
  Future<bool> _insertIfMissing(Isar isar, AppNotification n) async {
    final existing = await isar.notificationLocalModels
        .filter()
        .notificationIdEqualTo(n.id)
        .findFirst();
    if (existing != null) return false;
    await isar.notificationLocalModels.put(_toModel(n));
    return true;
  }

  NotificationLocalModel _toModel(AppNotification n) {
    return NotificationLocalModel()
      ..notificationId = n.id
      ..title = n.title
      ..body = n.body
      ..receivedAt = n.receivedAt
      ..applicationId = n.applicationId
      ..isRead = n.isRead;
  }

  AppNotification _toEntity(NotificationLocalModel model) {
    return AppNotification(
      id: model.notificationId,
      title: model.title,
      body: model.body,
      receivedAt: model.receivedAt,
      applicationId: model.applicationId,
      isRead: model.isRead,
    );
  }
}
