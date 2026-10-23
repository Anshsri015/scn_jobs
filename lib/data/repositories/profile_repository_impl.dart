import 'package:scn_jobs/data/datasources/profile_remote_datasource.dart';
import 'package:scn_jobs/domain/entities/language_selection.dart';
import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remoteDataSource);

  final ProfileRemoteDataSource _remoteDataSource;

  /// All master-data ids (`MasterDataItem.id`) are typed `String` in
  /// this app regardless of what the backend actually sent — every
  /// `fromJson` calls `.toString()` on the raw value (see
  /// `master_data_model.dart`'s class doc). `qualificationId` turned
  /// out to be a small integer server-side (`7`, not an ObjectId
  /// string) and sending it back as a JSON string crashed the backend
  /// with a 500 — see `EducationModel.toRequestBody`'s doc. Skills,
  /// languages, and preferred locations/industries all send ids back
  /// to the same `PATCH /worker/profile` surface, so they're exposed
  /// to the exact same risk. This converts each id back to a number
  /// when it parses cleanly as one, leaving anything that isn't
  /// (an actual ObjectId-style string) untouched.
  dynamic _asId(String id) => int.tryParse(id) ?? id;

  @override
  Future<WorkerProfile> createProfile() {
    return _remoteDataSource.createProfile();
  }

  @override
  Future<WorkerProfile> getProfile() {
    return _remoteDataSource.getProfile();
  }

  @override
  Future<WorkerProfile> updatePersonalDetails({
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? state,
    String? city,
    String? locality,
    String? photoUrl,
    String? headline,
    String? summary,
    int? totalExperienceMonths,
    int? expectedSalaryMin,
    int? expectedSalaryMax,
    String? alternatePhone,
    String? maritalStatus,
    String? category,
  }) {
    // ⚠️ Backend requires state + city + locality to be sent together —
    // sending city/locality without state (or vice versa) fails with
    // 400 "state, city and locality must all be provided together".
    // Callers must always pass all three or none of them.
    assert(
    (state == null && city == null && locality == null) ||
        (state != null && city != null && locality != null),
    'state, city, and locality must be passed together (or not at all)',
    );
    return _remoteDataSource.updateProfile({
      if (name != null) 'name': name,
      // Backend expects date-only "YYYY-MM-DD", not a full ISO8601
      // datetime with a time component.
      if (dateOfBirth != null)
        'dob':
        '${dateOfBirth.year.toString().padLeft(4, '0')}-${dateOfBirth.month.toString().padLeft(2, '0')}-${dateOfBirth.day.toString().padLeft(2, '0')}',
      if (gender != null) 'gender': gender,
      if (state != null) 'state': state,
      if (city != null) 'city': city,
      if (locality != null) 'locality': locality,
      if (photoUrl != null) 'profilePhotoUrl': photoUrl,
      if (headline != null) 'headline': headline,
      if (summary != null) 'summary': summary,
      if (totalExperienceMonths != null)
        'totalExperienceMonths': totalExperienceMonths,
      if (expectedSalaryMin != null) 'expectedSalaryMin': expectedSalaryMin,
      if (expectedSalaryMax != null) 'expectedSalaryMax': expectedSalaryMax,
      // Doc-confirmed fields (§6, POST/PATCH /worker/profile example
      // payloads) — `alternatePhone` free text, `maritalStatus` one
      // of the values the doc's own examples use (SINGLE/MARRIED).
      if (alternatePhone != null) 'alternatePhone': alternatePhone,
      if (maritalStatus != null) 'maritalStatus': maritalStatus,
      if (category != null) 'category': category,
    });
  }

  @override
  Future<WorkerProfile> updateSkills(List<String> skills) {
    // Same split as `updatePreferredIndustries` — confirmed with the
    // backend dev (15 Sep): there's no separate "create skill"
    // endpoint, custom entries are just sent as plain strings and the
    // backend find-or-creates them. Master-list selections are numeric
    // ids and go in the doc-confirmed `skillIds`; anything that
    // doesn't parse as an int is a typed-in name and goes in
    // `skillNames`. Sending a name inside `skillIds` is what produced
    // the 400 "Invalid value, field: skillIds[n]".
    final ids = <dynamic>[];
    final names = <String>[];
    for (final skill in skills) {
      final parsed = int.tryParse(skill);
      if (parsed != null) {
        ids.add(parsed);
      } else {
        names.add(skill);
      }
    }
    return _remoteDataSource.updateProfile({
      'skillIds': ids,
      if (names.isNotEmpty) 'skillNames': names,
    });
  }

  /// Sends `proficiency` for each language when the caller set one —
  /// omitted from that entry's map when null, matching the doc-noted
  /// `[{ languageId, proficiency? }]` shape (proficiency optional).
  @override
  Future<WorkerProfile> updateLanguages(List<LanguageSelection> languages) {
    return _remoteDataSource.updateProfile({
      'languages': languages
          .map((selection) => {
        'languageId': _asId(selection.languageId),
        if (selection.proficiency != null)
          'proficiency': selection.proficiency!.apiValue,
      })
          .toList(),
    });
  }

  @override
  Future<WorkerProfile> updatePreferredLocations(List<String> locations) {
    // Doc-confirmed (§6, POST/PATCH /worker/profile example payload):
    // master-list selections go in `preferredLocationIds` (numeric
    // ids) — not `preferredLocations` or `locationIds`, both of which
    // the backend silently ignored. Manually typed locations aren't
    // master ids, so they go in `locationNames` (same find-or-create
    // string pattern the backend dev confirmed on 15 Sep for
    // industries and skills). Mixing a typed name into
    // `preferredLocationIds` is exactly what produced the 400
    // "Invalid value, field: preferredLocationIds[1]".
    final ids = <dynamic>[];
    final names = <String>[];
    for (final location in locations) {
      final parsed = int.tryParse(location);
      if (parsed != null) {
        ids.add(parsed);
      } else {
        names.add(location);
      }
    }
    return _remoteDataSource.updateProfile({
      'preferredLocationIds': ids,
      if (names.isNotEmpty) 'locationNames': names,
    });
  }

  @override
  Future<WorkerProfile> updatePreferredIndustries(List<String> industries) {
    // Doc-confirmed (API reference §6, POST/PATCH /worker/profile):
    // real master-data selections go in `preferredIndustryIds` (numeric
    // ids), and anything that isn't a master-data id goes in
    // `industryNames` — the backend find-or-creates those by name, no
    // separate lookup call needed. Earlier guesses (`preferredIndustries`,
    // `industryIds` alone) were wrong; this is the field pair the doc
    // actually specifies. A selected chip's id always parses as an int
    // here, so splitting on that cleanly separates real ids from
    // custom-typed names.
    final ids = <dynamic>[];
    final names = <String>[];
    for (final industry in industries) {
      final parsed = int.tryParse(industry);
      if (parsed != null) {
        ids.add(parsed);
      } else {
        names.add(industry);
      }
    }
    return _remoteDataSource.updateProfile({
      'preferredIndustryIds': ids,
      if (names.isNotEmpty) 'industryNames': names,
    });
  }

  @override
  Future<WorkerProfile> updatePreferredJobRoles(List<String> jobRoleIds) {
    // Job Roles and Departments were sending EVERY id straight through
    // `_asId` (int-if-it-parses, else the raw string) with no id/name
    // split — that's exactly the mistake `updateSkills` /
    // `updatePreferredIndustries` / `updatePreferredLocations` already
    // ran into and fixed: a worker-typed custom value (e.g. "Add
    // ..." on the Job Roles/Departments picker) doesn't parse as an
    // int, so it went into the numeric-id field as a bare string and
    // the backend 400'd the whole PATCH — surfacing as "Couldn't
    // save" even though the rest of the selection was fine. Splitting
    // it the same way those three already do: real master-data
    // selections (parse as int) stay in the id field(s) below; typed
    // names go in a separate `jobRoleNames` field the backend
    // find-or-creates by name, same convention as `skillNames` /
    // `industryNames` / `locationNames`.
    final ids = <dynamic>[];
    final names = <String>[];
    for (final jobRole in jobRoleIds) {
      final parsed = int.tryParse(jobRole);
      if (parsed != null) {
        ids.add(parsed);
      } else {
        names.add(jobRole);
      }
    }
    return _remoteDataSource.updateProfile({
      'preferredJobRoles': ids,
      'jobRoleIds': ids,
      'preferredJobRoleIds': ids,
      if (names.isNotEmpty) 'jobRoleNames': names,
    });
  }

  @override
  Future<WorkerProfile> updatePreferredDepartments(List<String> departmentIds) {
    // Same id/name split as `updatePreferredJobRoles` above, and for
    // the same reason — a typed-in department name isn't a real id,
    // so it can't go through `_asId` into the numeric id field
    // alongside actual master-data selections without the backend
    // rejecting the whole PATCH.
    final ids = <dynamic>[];
    final names = <String>[];
    for (final department in departmentIds) {
      final parsed = int.tryParse(department);
      if (parsed != null) {
        ids.add(parsed);
      } else {
        names.add(department);
      }
    }
    return _remoteDataSource.updateProfile({
      'preferredDepartments': ids,
      'departmentIds': ids,
      if (names.isNotEmpty) 'departmentNames': names,
    });
  }

  @override
  Future<WorkerProfile> updateAssets(List<String> assetNames) {
    // Plain names, not ids — see `WorkerProfile.assets`'s doc.
    return _remoteDataSource.updateProfile({'assets': assetNames});
  }

  /// Deliberately does NOT `PATCH resumeUrl` — the API doc is explicit
  /// that `POST /uploadthing (resumeUploader)` saves `resumeUrl` onto
  /// the profile server-side on completion, and `resumeUrl` isn't even
  /// in `PATCH /worker/profile`'s accepted field list — it's set
  /// server-side by the upload provider's webhook, asynchronously,
  /// outside this request/response cycle. Poll `getProfile()` a few
  /// times with a short delay so the webhook has a real chance to land
  /// before this returns — [resumeUrl] is only used to know what value
  /// we're waiting to see appear; it's not sent back to the server.
  ///
  /// CONFIRMED (12 Sep, via device log comparing two full signups):
  /// `profileComplete` is NOT recalculated when the resume webhook
  /// lands, no matter how long you wait — one test polled 13 minutes
  /// past the webhook landing and `profileComplete` was still `false`.
  /// It only flips the moment the NEXT `PATCH /worker/profile` call
  /// (any field) goes out — confirmed in the same log: a plain
  /// personal-details PATCH sent minutes later, with nothing to do
  /// with the resume, was immediately followed by `profileComplete:
  /// true` on the next GET. That's why redoing the whole wizard a
  /// second time "fixed" it — the 2nd run's PATCH calls (skills,
  /// languages, locations, industries...) forced the recompute, not
  /// the passage of time. So once the webhook has landed (resumeUrl is
  /// non-empty), fire one harmless PATCH — echoing back a field the
  /// worker already set — purely to trigger that recompute. This makes
  /// the profile complete on the FIRST run, no second signup needed.
  @override
  Future<WorkerProfile> updateResumeUrl(String resumeUrl) async {
    const maxAttempts = 5;
    const delayBetweenAttempts = Duration(seconds: 2);

    WorkerProfile profile = await _remoteDataSource.getProfile();
    for (var attempt = 1;
    attempt < maxAttempts && (profile.resumeUrl == null || profile.resumeUrl!.isEmpty);
    attempt++) {
      await Future.delayed(delayBetweenAttempts);
      profile = await _remoteDataSource.getProfile();
    }

    // Webhook has landed (or we gave up waiting) — nudge the backend
    // to recompute `profileComplete` by echoing back a field it
    // already has. `isFresher` is always set by this point (Personal
    // Details is an earlier, mandatory wizard step), so this is a
    // true no-op write, not a real change.
    if (profile.resumeUrl != null && profile.resumeUrl!.isNotEmpty) {
      try {
        profile = await _remoteDataSource.updateProfile(
          {'isFresher': profile.isFresher ?? false},
        );
      } catch (_) {
        // Nudge failing shouldn't block the flow — worst case we fall
        // back to the old "complete on 2nd wizard run" behaviour.
      }
    }
    return profile;
  }

  @override
  Future<WorkerProfile> updateWorkingStatus({
    bool? isFresher,
    String? workingStatus,
    int? noticePeriodDays,
  }) {
    return _remoteDataSource.updateProfile({
      if (isFresher != null) 'isFresher': isFresher,
      if (workingStatus != null) 'workingStatus': workingStatus,
      if (noticePeriodDays != null) 'noticePeriodDays': noticePeriodDays,
    });
  }
}