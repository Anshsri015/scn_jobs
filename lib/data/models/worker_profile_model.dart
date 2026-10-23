import 'package:scn_jobs/data/models/education_model.dart';
import 'package:scn_jobs/data/models/experience_model.dart';
import 'package:scn_jobs/domain/entities/language_selection.dart';
import 'package:scn_jobs/domain/entities/worker_profile.dart';

/// Maps `WorkerProfile` to/from `GET /worker/profile`'s JSON shape.
///
/// `GET /worker/profile` doc note says education/experience/languages/
/// preferences all come "included" — [fromJson] parses them as nested
/// arrays. If the real response turns out flatter (e.g. education
/// fetched separately), only this factory needs to change —
/// `EducationRepositoryImpl`/`ExperienceRepositoryImpl` both go through
/// `ProfileRemoteDataSource.getProfile()` for their `list()`, so a
/// parsing fix here fixes both at once.
///
/// `languages` now carries `proficiency` alongside each `languageId`,
/// matching the API's `[{ languageId, proficiency? }]` shape —
/// previously this was flattened to a bare `List<String>` and
/// proficiency was dropped on read / never sent on write.
class WorkerProfileModel extends WorkerProfile {
  const WorkerProfileModel({
    required super.userId,
    super.name,
    super.dateOfBirth,
    super.gender,
    super.state,
    super.city,
    super.locality,
    super.photoUrl,
    super.resumeUrl,
    super.headline,
    super.summary,
    super.totalExperienceMonths,
    super.expectedSalaryMin,
    super.expectedSalaryMax,
    super.education,
    super.experience,
    super.skills,
    super.languages,
    super.preferredLocations,
    super.preferredIndustries,
    super.preferredJobRoles,
    super.preferredDepartments,
    super.assets,
    super.category,
    super.isComplete,
    super.maritalStatus,
    super.alternatePhone,
  });

  factory WorkerProfileModel.fromJson(Map<String, dynamic> json) {
    final educationJson = json['education'] as List? ?? const [];
    final experienceJson = json['experience'] as List? ?? const [];
    final languagesJson = json['languages'] as List? ?? const [];

    return WorkerProfileModel(
      userId: json['userId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      dateOfBirth: json['dob'] != null
          ? DateTime.tryParse(json['dob'].toString())
          : null,
      gender: json['gender']?.toString(),
      state: json['state']?.toString(),
      city: json['city']?.toString(),
      // Doc-confirmed GET key is `currentLocality` (see this file's
      // class doc / `WorkerProfile`'s doc) — was reading `locality`
      // only, which the response never actually has, so this always
      // came back null and the Location section on Personal Details
      // never had anything to prefill. `locality` kept as a fallback
      // in case an older response shape is ever replayed.
      locality: (json['currentLocality'] ?? json['locality'])?.toString(),
      photoUrl: json['profilePhotoUrl']?.toString(),
      resumeUrl: json['resumeUrl']?.toString(),
      headline: json['headline']?.toString(),
      summary: json['summary']?.toString(),
      totalExperienceMonths: json['totalExperienceMonths'] as int?,
      expectedSalaryMin: json['expectedSalaryMin'] as int?,
      expectedSalaryMax: json['expectedSalaryMax'] as int?,
      education: educationJson
          .map((e) => EducationModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      experience: experienceJson
          .map((e) => ExperienceModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      // ⚠️ BUG FOUND (confirmed via live logcat trace, 11 Sep): the real
      // `GET`/`PATCH /worker/profile` response uses `skills`,
      // `preferredIndustries`, `preferredJobRoles`, `preferredDepartments`,
      // `preferredLocations` — NO `Ids` suffix on any of them. The doc
      // examples this was originally built against apparently showed a
      // different (request-only?) shape; the actual live response's
      // top-level keys were confirmed directly:
      // `[..., skills, languages, preferredLocations, preferredIndustries,
      // preferredDepartments, preferredJobRoles]`. Reading the old
      // `<x>Ids` keys always returned null → silently fell back to `[]`
      // every time, so these 4 sections (+ locations) displayed "None"
      // forever even after a successful save. `_idsFromList` below also
      // defensively unwraps `{id, name}`-style objects in case these
      // come back populated rather than as bare id strings — we haven't
      // fully confirmed the item shape yet, only that the *key* was
      // wrong, so this covers both possibilities without another
      // round-trip.
      skills: _idsFromList(
        json['skills'],
        foreignKey: 'skillId',
        nestedKey: 'skill',
      ),
      languages: languagesJson
          .map((e) {
        final map = e as Map;
        final id = map['languageId']?.toString() ?? '';
        if (id.isEmpty) return null;
        return LanguageSelection(
          languageId: id,
          proficiency: LanguageProficiency.fromApiValue(
              map['proficiency']?.toString()),
        );
      })
          .whereType<LanguageSelection>()
          .toList(),
      preferredLocations: _idsFromList(
        json['preferredLocations'],
        foreignKey: 'locationId',
        nestedKey: 'location',
      ),
      preferredIndustries: _idsFromList(
        json['preferredIndustries'],
        foreignKey: 'industryId',
        nestedKey: 'industry',
      ),
      preferredJobRoles: _idsFromList(
        json['preferredJobRoles'],
        foreignKey: 'jobRoleId',
        nestedKey: 'jobRole',
      ),
      preferredDepartments: _idsFromList(
        json['preferredDepartments'],
        foreignKey: 'departmentId',
        nestedKey: 'department',
      ),
      // Plain names, not ids — see `WorkerProfile.assets`'s doc.
      assets: (json['assets'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      category: json['category']?.toString(),
      // WHY: doc-confirmed key is `profileComplete` (see
      // `POST/GET /worker/profile` response examples), NOT
      // `isComplete`. The old code read `json['isComplete']`, which
      // never exists in a real response — so this field silently
      // defaulted to `false` on every single load, no matter what the
      // backend actually said. Kept a fallback check on the old key
      // too, purely defensive, in case an older cached response shape
      // is ever replayed.
      isComplete: json['profileComplete'] as bool? ??
          json['isComplete'] as bool? ??
          false,
      // Same key names used on the `PATCH /worker/profile` write side
      // (`profile_repository_impl.dart`) — reading them back symmetrically,
      // same as every other field in this factory. These were entirely
      // unmodeled before (no field on `WorkerProfile` at all), so even
      // though the backend was almost certainly returning them, the app
      // silently dropped them on every load.
      maritalStatus: json['maritalStatus']?.toString(),
      alternatePhone: json['alternatePhone']?.toString(),
    );
  }

  /// Unwraps a preference-list field into plain id strings.
  ///
  /// ⚠️ BUG FOUND (confirmed via live logcat trace, 11 Sep — the
  /// `PATCH /worker/profile — PREFERENCE FIELDS` block): the real item
  /// shape is a **join row**, not a bare id and not a plain
  /// `{id, name}` object:
  /// ```
  /// {workerId: ..., skillId: 1, skill: {id: 1, name: Abrasives, ...}}
  /// ```
  /// The actual id lives in the join row's own foreign-key field
  /// (`skillId`/`industryId`/`jobRoleId`/`departmentId`/`locationId`
  /// depending on which list this is) — it is *not* under `id`/`_id`
  /// on the join row itself, which is what the previous version of
  /// this helper checked. That's why every one of these sections kept
  /// showing "None" even after the key-name fix: the key was right,
  /// but every item inside got filtered out because `id`/`_id` was
  /// never present at that level, so the whole list collapsed to `[]`.
  ///
  /// [foreignKey] is that join row's own id field (e.g. `skillId`).
  /// [nestedKey] is the nested populated object (e.g. `skill`), used
  /// as a fallback if [foreignKey] is ever missing. Bare id lists
  /// (`[11, 23]`) and bare `{id, name}` objects (no join wrapper) are
  /// still handled too, so this keeps working if the backend response
  /// shape ever changes again.
  static List<String> _idsFromList(
      dynamic raw, {
        String? foreignKey,
        String? nestedKey,
      }) {
    if (raw is! List) return const [];
    return raw
        .map((e) {
      if (e is! Map) return e?.toString();
      if (foreignKey != null && e[foreignKey] != null) {
        return e[foreignKey].toString();
      }
      if (nestedKey != null && e[nestedKey] is Map) {
        final nested = e[nestedKey] as Map;
        final nestedId = nested['id'] ?? nested['_id'];
        if (nestedId != null) return nestedId.toString();
      }
      return (e['id'] ?? e['_id'])?.toString();
    })
        .whereType<String>()
        .toList();
  }
}
