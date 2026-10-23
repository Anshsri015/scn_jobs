import 'package:scn_jobs/domain/entities/education.dart';
import 'package:scn_jobs/domain/entities/experience.dart';
import 'package:scn_jobs/domain/entities/language_selection.dart';

/// The worker's profile — built incrementally across the Day 9-14
/// profile-setup flow (create blank → personal details → education →
/// experience → skills/languages/locations → resume).
///
/// Field set is confirmed against the Profile API doc (`PATCH
/// /worker/profile`): `name` (not `fullName` — renamed to match the
/// backend field), `phone`, `dob`, `gender`, `city`, `currentLocality`,
/// `profilePhotoUrl`, `headline`, `summary`, `totalExperienceMonths`,
/// `expectedSalaryMin`, `expectedSalaryMax`, `skillIds[]`,
/// `languages[]`, `preferredLocationIds[]`, `preferredIndustryIds[]`.
///
/// [isComplete] reflects whether every mandatory section has been
/// filled — the exact definition of "complete" (which sections are
/// mandatory vs optional) isn't confirmed yet; this field exists so
/// `route_guards.dart` can gate access to Jobs/Applications on it once
/// that's decided, without every screen re-deriving completeness from
/// scratch.
class WorkerProfile {
  const WorkerProfile({
    required this.userId,
    this.name,
    this.dateOfBirth,
    this.gender,
    this.state,
    this.city,
    this.locality,
    this.photoUrl,
    this.resumeUrl,
    this.headline,
    this.summary,
    this.totalExperienceMonths,
    this.expectedSalaryMin,
    this.expectedSalaryMax,
    this.education = const [],
    this.experience = const [],
    this.skills = const [],
    this.languages = const [],
    this.preferredLocations = const [],
    this.preferredIndustries = const [],
    this.preferredJobRoles = const [],
    this.preferredDepartments = const [],
    this.assets = const [],
    this.category,
    this.isComplete = false, this.isFresher, this.workingStatus, this.noticePeriodDays,
    this.maritalStatus,
    this.alternatePhone,
  });

  final String userId;
  final String? name;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? state;
  final String? city;
  final String? locality;
  final String? photoUrl;
  final String? resumeUrl;
  final String? headline;
  final String? summary;
  final int? totalExperienceMonths;
  final int? expectedSalaryMin;
  final int? expectedSalaryMax;
  final List<Education> education;
  final List<Experience> experience;
  final List<String> skills;
  final List<LanguageSelection> languages;
  final List<String> preferredLocations;
  final List<String> preferredIndustries;
  /// `JobRoleItem.id`s — matches `preferredJobRoleIds` in the API doc
  /// (`POST /worker/profile`'s alternate payload example).
  final List<String> preferredJobRoles;
  /// `JobFunctionItem.id`s. The doc's create payload also accepts a
  /// find-or-create `departmentNames` list; this holds the resolved
  /// ids as read back from the profile, same pattern as
  /// [preferredIndustries].
  final List<String> preferredDepartments;
  /// Plain names, not ids (see `AssetItem`'s doc / the API doc's
  /// `"assets": ["OwnLaptop", "TwoWheeler"]` example) — equipment the
  /// worker self-reports owning.
  final List<String> assets;
  /// Reservation category — one of the values the backend's `POST
  /// /worker/profile` example payloads use (e.g. "GEN", "OBC").
  final String? category;
  final bool isComplete;
  final bool? isFresher;
  final String? workingStatus; // 'SERVING_NOTICE' | 'WORKING' | 'NOT_WORKING' | 'IMMEDIATE_JOINER'
  final int? noticePeriodDays;
  final String? maritalStatus; // 'SINGLE' | 'MARRIED'
  // The worker's WhatsApp number when it differs from their verified
  // primary phone. Null both when it's never been set AND when it's
  // the same as the primary — the two aren't distinguishable from
  // this field alone (matches how `updatePersonalDetails` sends it).
  final String? alternatePhone;

  WorkerProfile copyWith({
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? state,
    String? city,
    String? locality,
    String? photoUrl,
    String? resumeUrl,
    String? headline,
    String? summary,
    int? totalExperienceMonths,
    int? expectedSalaryMin,
    int? expectedSalaryMax,
    List<Education>? education,
    List<Experience>? experience,
    List<String>? skills,
    List<LanguageSelection>? languages,
    List<String>? preferredLocations,
    List<String>? preferredIndustries,
    List<String>? preferredJobRoles,
    List<String>? preferredDepartments,
    List<String>? assets,
    String? category,
    bool? isComplete, bool? isFresher,String? workingStatus,int? noticePeriodDays,
    String? maritalStatus,
    String? alternatePhone,
  }) {
    return WorkerProfile(
      userId: userId,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      state: state ?? this.state,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      photoUrl: photoUrl ?? this.photoUrl,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      headline: headline ?? this.headline,
      summary: summary ?? this.summary,
      totalExperienceMonths:
      totalExperienceMonths ?? this.totalExperienceMonths,
      expectedSalaryMin: expectedSalaryMin ?? this.expectedSalaryMin,
      expectedSalaryMax: expectedSalaryMax ?? this.expectedSalaryMax,
      education: education ?? this.education,
      experience: experience ?? this.experience,
      skills: skills ?? this.skills,
      languages: languages ?? this.languages,
      preferredLocations: preferredLocations ?? this.preferredLocations,
      preferredIndustries: preferredIndustries ?? this.preferredIndustries,
      preferredJobRoles: preferredJobRoles ?? this.preferredJobRoles,
      preferredDepartments: preferredDepartments ?? this.preferredDepartments,
      assets: assets ?? this.assets,
      category: category ?? this.category,
      isComplete: isComplete ?? this.isComplete,
      isFresher: isFresher ?? this.isFresher,
      workingStatus: workingStatus ?? this.workingStatus,
      noticePeriodDays: noticePeriodDays ?? this.noticePeriodDays,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      alternatePhone: alternatePhone ?? this.alternatePhone,

    );
  }
}

// WHY THIS FILE CHANGED (from the pre-API-doc scaffold)
// `fullName` → `name`: matches the confirmed `PATCH /worker/profile`
// body field exactly, so the data-layer model (pending) maps 1:1
// instead of needing a rename at the JSON boundary.
// Added `headline`, `summary`, `totalExperienceMonths`,
// `expectedSalaryMin`, `expectedSalaryMax` — all real fields the API
// accepts that the old scaffold had no slot for at all; without them
// there'd be no way to ever set these from the app.
// `phone` and `profilePhotoUrl`-as-a-settable-field are still NOT
// modeled here on purpose: `phone` isn't editable from any current
// screen's flow, and `profilePhotoUrl` is only ever set indirectly via
// `updateResumeUrlUseCase`'s sibling (the photo-upload use case), never
// typed in directly — same reasoning as `resumeUrl`.
// Pitfall a junior would hit: adding a UI field for one of the new
// properties (e.g. a headline text box) without also adding the
// matching named parameter to `ProfileRepository.updatePersonalDetails`
// — the entity accepting a field doesn't mean the update path sends it.
