import 'package:scn_jobs/domain/entities/education.dart';

/// Maps `Education` to/from the `/worker/education` JSON shape.
///
/// [fromJson] follows the code-verified doc's response shape (`id`,
/// `level`, `institute` — no `qualification` object is echoed back),
/// so [Education.qualificationName] always starts null on load;
/// `EducationRepositoryImpl`/the list screen re-populate it locally by
/// matching [qualificationId] + [level] against
/// `MasterRepository.getQualifications()`.
class EducationModel extends Education {
  const EducationModel({
    required super.id,
    required super.level,
    super.qualificationId,
    super.qualificationName,
    super.institute,
  });

  factory EducationModel.fromJson(Map<String, dynamic> json) {
    // ⚠️ BUG FOUND (confirmed via live logcat trace, 11 Sep — the
    // `--- education (raw) ---` debug block): the real response has
    // NO top-level `level` key at all. Its actual keys are `[id,
    // workerId, qualificationId, institute, passoutYear, score,
    // qualification]` — `level` (and the qualification's display name)
    // live nested inside `qualification: {id, name, level, isActive}`,
    // same join-row pattern as skills/preferredIndustries/etc. Reading
    // `json['level']` directly always returned null -> defaulted to
    // `'ANY'` -> showed "Other / Certification" no matter what was
    // actually picked when adding the entry. Falling back to the
    // nested `qualification.level` fixes this; the top-level key is
    // kept as a first check in case the backend ever adds it directly.
    //
    // Also: `qualification.name` (e.g. "B.Tech") IS present here,
    // contrary to this file's old doc note above claiming it's never
    // echoed back — reading it now means the screen doesn't need a
    // separate master-data match to show a real name instead of a
    // raw id.
    final qualification = json['qualification'];
    final nestedLevel =
    qualification is Map ? qualification['level']?.toString() : null;
    final nestedName =
    qualification is Map ? qualification['name']?.toString() : null;
    return EducationModel(
      id: json['id']?.toString() ?? '',
      level: json['level']?.toString() ?? nestedLevel ?? 'ANY',
      qualificationId: json['qualificationId']?.toString(),
      qualificationName: nestedName,
      institute: json['institute']?.toString(),
    );
  }

  /// Body for `POST`/`PATCH /worker/education` — only the fields the
  /// endpoint accepts; [id] is never sent (path param on
  /// PATCH/DELETE, backend-assigned on POST).
  ///
  /// `level` is always required. Below it, EXACTLY one of
  /// `qualificationId` / `qualificationName` goes out, matching the
  /// doc's two example payloads:
  /// - `level != ANY` -> `qualificationId` (must be set — the form
  ///   screen enforces this before calling the use case).
  /// - `level == ANY` -> `qualificationName` (free text), never
  ///   `qualificationId`.
  ///
  /// `qualificationId` is sent as a number when it parses cleanly as
  /// one (ids looked like small integers in testing, not Mongo
  /// ObjectIds) and falls back to the original string otherwise.
  Map<String, dynamic> toRequestBody() {
    return {
      'level': level,
      if (level != 'ANY' && qualificationId != null)
        'qualificationId': int.tryParse(qualificationId!) ?? qualificationId,
      if (level == 'ANY' &&
          qualificationName != null &&
          qualificationName!.trim().isNotEmpty)
        'qualificationName': qualificationName!.trim(),
      if (institute != null && institute!.trim().isNotEmpty)
        'institute': institute!.trim(),
    };
  }
}
