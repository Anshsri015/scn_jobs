import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:scn_jobs/core/error/exceptions.dart';
import 'package:scn_jobs/core/utils/logger.dart';

/// Opens and holds the single [Isar] instance for the app's lifetime.
///
/// No collection schemas exist yet — those arrive with their owning
/// domain (e.g. `JobModel`'s schema on Day 15). [init] takes the schema
/// list as a parameter precisely so this file never needs to import a
/// feature's model class; `main.dart` assembles the full schema list
/// and passes it in, keeping this a pure infrastructure file.
class IsarService {
  IsarService._();

  static final IsarService instance = IsarService._();

  Isar? _isar;

  /// The live [Isar] instance. Throws [CacheException] if accessed
  /// before [init] completes — a programming error, not a runtime one,
  /// so this fails loudly rather than returning null.
  Isar get isar {
    final instance = _isar;
    if (instance == null) {
      throw const CacheException(
        'IsarService.init() must be awaited before use.',
      );
    }
    return instance;
  }

  bool get isInitialized => _isar != null;

  /// Call once, early in `main()`, before `runApp`. Idempotent — calling
  /// twice returns the existing instance instead of reopening.
  Future<Isar> init({required List<CollectionSchema<dynamic>> schemas}) async {
    if (_isar != null) return _isar!;

    try {
      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        schemas,
        directory: dir.path,
        inspector: false,
      );
      AppLogger.i(
        'Isar opened at ${dir.path} with ${schemas.length} schema(s)',
      );
      return _isar!;
    } catch (e, st) {
      AppLogger.e('Failed to open Isar', e, st);
      throw const CacheException('Could not initialize local storage.');
    }
  }

  /// Wipes every collection — called on logout so no other worker's
  /// cached jobs/applications/profile data lingers for the next login
  /// on a shared device. Safe no-op if Isar hasn't been opened yet
  /// (still true as of Day 7 — the first schema lands Day 15, and
  /// `main.dart` doesn't call [init] until then either), so
  /// `LogoutUseCase` can call this unconditionally without checking
  /// [isInitialized] itself.
  Future<void> clearAllData() async {
    final instance = _isar;
    if (instance == null) return;
    await instance.writeTxn(instance.clear);
  }

  Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
