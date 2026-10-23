import 'package:scn_jobs/domain/entities/language_selection.dart';
import 'package:scn_jobs/domain/entities/worker_profile.dart';

abstract class ProfileRepository {
  /// Creates a blank profile server-side — the mandatory first step
  /// after verify-otp/login before any other profile-setup screen is
  /// reachable (`CreateProfileScreen`, Day 9, calls this once).
  Future<WorkerProfile> createProfile();

  Future<WorkerProfile> getProfile();

  /// Partial update — only non-null parameters are sent, matching
  /// `PATCH /worker/profile`'s confirmed partial-update contract.
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
  });

  Future<WorkerProfile> updateSkills(List<String> skills);

  Future<WorkerProfile> updateLanguages(List<LanguageSelection> languages);

  Future<WorkerProfile> updatePreferredLocations(List<String> locations);

  Future<WorkerProfile> updatePreferredIndustries(List<String> industries);

  /// [jobRoleIds] — `JobRoleItem.id`s, matches `preferredJobRoleIds`.
  Future<WorkerProfile> updatePreferredJobRoles(List<String> jobRoleIds);

  /// [departmentIds] — `JobFunctionItem.id`s, sent as
  /// `preferredDepartmentIds` (same pattern as preferred industries).
  Future<WorkerProfile> updatePreferredDepartments(List<String> departmentIds);

  /// [assetNames] — plain names, not ids (see `WorkerProfile.assets`).
  Future<WorkerProfile> updateAssets(List<String> assetNames);

  Future<WorkerProfile> updateResumeUrl(String resumeUrl);

  /// Doc-confirmed fields on `PATCH /worker/profile` (§6, second
  /// example payload): `isFresher`, `workingStatus` (WORKING |
  /// NOT_WORKING | IMMEDIATE_JOINER | SERVING_NOTICE), and
  /// `noticePeriodDays` — required by the backend only when
  /// `workingStatus` is SERVING_NOTICE, but that's the backend's
  /// validation to enforce, not this layer's; it's sent whenever
  /// non-null here.
  Future<WorkerProfile> updateWorkingStatus({
    bool? isFresher,
    String? workingStatus,
    int? noticePeriodDays,
  });
}

