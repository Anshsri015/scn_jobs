/// ✅ Rebuilt against the code-verified SCN Jobs API doc (Section 7,
/// `/jobs`), which is much richer than the earlier best-guess scaffold
/// and matches the confirmed job-detail screenshots.
///
/// `description`, `responsibilities`, `jobType`, and `shiftType` are
/// confirmed real fields (raw job payload dump, 2026-09-11) — not
/// derived/guessed. `highlights` is a separate free-text notes field,
/// NOT the same as `responsibilities`.
///
/// Deliberately NOT included, because they are not part of the
/// documented `/jobs` contract:
/// - Recruiter star rating / review count, a "Job match score" (Early
///   Applicant / Keyskills / Location / Work Experience badges), and
///   an applicant count on the card — none of these appear anywhere
///   in the doc. If the backend team confirms an endpoint for them,
///   add the fields then; don't fabricate placeholder numbers.
class Job {
  const Job({
    required this.id,
    required this.title,
    required this.companyName,
    this.status,
    this.locationName,
    this.salaryMin,
    this.salaryMax,
    this.wagePeriod,
    this.headcountRequired,
    this.gender,
    this.workingDays,
    this.freshersOnly = false,
    this.workingStatus,
    this.minExperienceMonths,
    this.maxExperienceMonths,
    this.industryName,
    this.functionName,
    this.highlights = const [],
    this.skillNames = const [],
    this.benefitNames = const [],
    this.assetNames = const [],
    this.qualificationNames = const [],
    this.languages = const [],
    this.postedAt,
    this.description,
    this.recruiterEmail,
    this.recruiterPhone,
    this.responsibilities = const [],
    this.jobType,
    this.shiftType,
  });

  final String id;

  /// `jobRoleName` from the API — there's no separate "job title"
  /// field server-side, the role name IS the title.
  final String title;
  final String companyName;

  /// 'draft' | 'active' | 'closed'.
  final String? status;

  final String? locationName;

  final int? salaryMin;
  final int? salaryMax;

  /// 'daily' | 'monthly' | 'yearly' — whichever wage pair was filled.
  final String? wagePeriod;

  /// Maps directly to `headcountRequired` — the doc-confirmed field
  /// behind the screenshot's "Openings: 3".
  final int? headcountRequired;

  /// 'ANY' | 'MALE' | 'FEMALE'.
  final String? gender;

  /// 'FIVE_DAYS' | 'SIX_DAYS'.
  final String? workingDays;

  final bool freshersOnly;

  /// Only meaningful when [freshersOnly] is false — 'WORKING' |
  /// 'NOT_WORKING' | 'IMMEDIATE_JOINER' | 'SERVING_NOTICE'.
  final String? workingStatus;

  final int? minExperienceMonths;
  final int? maxExperienceMonths;

  final String? industryName;
  final String? functionName;

  /// Free-text bullet points the recruiter wrote — `highlights` in
  /// the doc. This is the real, documented equivalent of the
  /// screenshot's "Job highlights" section.
  final List<String> highlights;

  final List<String> skillNames;
  final List<String> benefitNames;
  final List<String> assetNames;
  final List<String> qualificationNames;
  final List<String> languages;

  final DateTime? postedAt;

  /// Free-text role description — confirmed real field (raw job
  /// payload dump, 2026-09-11).
  final String? description;

  /// The posting recruiter's email, resolved the same defensive way
  /// [companyName] already is (from `poster.recruiter` / `recruiter`
  /// in the raw job JSON) — nullable, since a worker-facing `/jobs`
  /// response isn't guaranteed to include it.
  final String? recruiterEmail;

  /// The job **poster's** phone number — confirmed (raw job payload
  /// dump, 2026-09-11) to live at `poster.phone`, a SIBLING of the
  /// nested `poster.recruiter` object, not inside it. Same
  /// backend pattern as the education/skills nested-field bugs: don't
  /// assume it's nested just because the other recruiter fields are.
  final String? recruiterPhone;

  /// Real bullet-point responsibilities from the API's `responsibilities`
  /// array. NOT the same as [highlights] — that's a separate free-text
  /// notes field (e.g. "This job for only male candidates"), confirmed
  /// from a raw job payload dump on 2026-09-11.
  final List<String> responsibilities;

  /// Raw backend slug — 'full_time' | 'part_time' | 'contract' | etc.
  /// [jobTypeLabel] turns this into a display string.
  final String? jobType;

  /// Raw backend slug — 'day' | 'night' | 'rotational' | etc.
  /// [shiftTypeLabel] turns this into a display string.
  final String? shiftType;

  bool get hasSalaryRange => salaryMin != null || salaryMax != null;

  /// e.g. "/day", "/month", "/year" — empty string if [wagePeriod] is
  /// unknown, so callers can safely concatenate without a null check.
  String get wagePeriodSuffix => switch (wagePeriod) {
    'daily' => '/day',
    'monthly' => '/month',
    'yearly' => '/year',
    _ => '',
  };

  /// "Full-Time" / "Part-Time" style label built from [freshersOnly]/
  /// [workingStatus] — the API has no separate "employment type"
  /// field, so this is a derived display string, not a raw backend
  /// value.
  ///
  /// NOT what the website's "Job Type" / "Employment Type" fields
  /// show — those come from the real [jobType]/[shiftType] fields
  /// below (confirmed from a raw job payload dump). Kept here only
  /// because other screens may still reference it; prefer
  /// [jobTypeLabel]/[employmentTypeDisplay] for anything matching the
  /// website's job-detail layout.
  String get employmentTypeLabel {
    if (freshersOnly) return 'Freshers Welcome';
    return switch (workingStatus) {
      'IMMEDIATE_JOINER' => 'Immediate Joiner',
      'SERVING_NOTICE' => 'Notice Period OK',
      'NOT_WORKING' => 'Open to Non-working Candidates',
      'WORKING' => 'Currently Working',
      _ => 'Full-Time',
    };
  }

  /// "Full-Time" / "Part-Time" / "Contract" — from the real `jobType`
  /// backend field. This is what the website's "Job Type:" line shows.
  String get jobTypeLabel => switch (jobType) {
    'full_time' => 'Full-Time',
    'part_time' => 'Part-Time',
    'contract' => 'Contract',
    _ => 'Not specified',
  };

  /// "Day Shift" / "Night Shift" / "Rotational Shift" — from the real
  /// `shiftType` backend field, or null if unknown.
  String? get shiftTypeLabel => switch (shiftType) {
    'day' => 'Day Shift',
    'night' => 'Night Shift',
    'rotational' => 'Rotational Shift',
    _ => null,
  };

  /// "Full-Time, Rotational Shift" — matches the website's
  /// "Employment Type:" line (jobType + shiftType combined).
  String get employmentTypeDisplay {
    final shift = shiftTypeLabel;
    return shift == null ? jobTypeLabel : '$jobTypeLabel, $shift';
  }

  /// "5 Days" / "6 Days" — derived from the raw `workingDays` enum.
  String get workingDaysLabel => switch (workingDays) {
    'FIVE_DAYS' => '5 Days',
    'SIX_DAYS' => '6 Days',
    _ => 'Not specified',
  };

  /// "Any" / "Male" / "Female" — derived from the raw `gender` enum.
  String get genderLabel => switch (gender) {
    'MALE' => 'Male',
    'FEMALE' => 'Female',
    'ANY' => 'Any',
    _ => 'Any',
  };

  /// Only meaningful when [freshersOnly] is false. Derived from the
  /// raw `workingStatus` enum — null when there's nothing to show
  /// (freshers-only jobs never send this field, per the doc).
  String? get workingStatusLabel {
    if (freshersOnly) return null;
    return switch (workingStatus) {
      'IMMEDIATE_JOINER' => 'Immediate Joiner',
      'SERVING_NOTICE' => 'Serving Notice',
      'NOT_WORKING' => 'Not Currently Working',
      'WORKING' => 'Currently Working',
      _ => null,
    };
  }

  /// "1-2 years" (when both bounds land on whole years) or a mixed
  /// "6 months - 1 year 6 months" style label otherwise — or null if
  /// the job has neither bound (e.g. freshers-only jobs, where the doc
  /// says these must NOT be sent at all). Raw values are still months
  /// under the hood (`minExperienceMonths`/`maxExperienceMonths`, per
  /// the doc) — this only changes the display, matching how other job
  /// apps show experience ranges in years rather than raw months.
  String? get experienceRangeLabel {
    final min = minExperienceMonths;
    final max = maxExperienceMonths;
    if (min == null && max == null) return null;
    if (min != null && max != null) {
      if (min % 12 == 0 && max % 12 == 0) {
        final minY = min ~/ 12;
        final maxY = max ~/ 12;
        return '$minY-$maxY year${maxY == 1 ? '' : 's'}';
      }
      return '${_formatExperienceDuration(min)} - ${_formatExperienceDuration(max)}';
    }
    if (min != null) return '${_formatExperienceDuration(min)}+';
    return 'Up to ${_formatExperienceDuration(max!)}';
  }

  /// "6 months" / "1 year" / "1 year 6 months" — used for the bound(s)
  /// that don't cleanly land on a whole-year range.
  static String _formatExperienceDuration(int months) {
    if (months < 12) {
      return '$months month${months == 1 ? '' : 's'}';
    }
    final years = months ~/ 12;
    final remMonths = months % 12;
    final yearsPart = '$years year${years == 1 ? '' : 's'}';
    if (remMonths == 0) return yearsPart;
    return '$yearsPart $remMonths month${remMonths == 1 ? '' : 's'}';
  }
}

// WHY THIS FILE CHANGED
// The old scaffold had `description`/`requirements`/a single
// `jobType` string — none of which the code-verified doc supports.
// This rebuild trades those guessed fields for the actual documented
// shape (`headcountRequired`, `workingDays`, `freshersOnly`/
// `workingStatus`, `highlights`, `skillIds`/`benefitNames`/
// `assetNames`/`qualificationIds`) so `JobDetailScreen` can show real
// data instead of hardcoded placeholder strings like "Posted 2 days
// ago" / "Vacancies: Multiple".
// Pitfall a junior would hit: trying to render a rating/review/match-
// score UI (visible in the reference screenshots) by inventing fields
// on this entity — those aren't in the API doc, so wiring them here
// would silently always show 0/blank instead of failing loudly. Flag
// to product/backend instead of faking the field.
