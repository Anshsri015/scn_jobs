import '../../domain/entities/job.dart';

class JobModel extends Job {
  const JobModel({
    required super.id,
    required super.title,
    required super.companyName,
    super.status,
    super.locationName,
    super.salaryMin,
    super.salaryMax,
    super.wagePeriod,
    super.headcountRequired,
    super.gender,
    super.workingDays,
    super.freshersOnly,
    super.workingStatus,
    super.minExperienceMonths,
    super.maxExperienceMonths,
    super.industryName,
    super.functionName,
    super.highlights,
    super.skillNames,
    super.benefitNames,
    super.assetNames,
    super.qualificationNames,
    super.languages,
    super.postedAt,
    super.description,
    super.recruiterEmail,
    super.recruiterPhone,
    super.responsibilities,
    super.jobType,
    super.shiftType,
  });

  /// Pulls a display name out of a master-data relation that the
  /// backend may nest under different keys depending on the endpoint
  /// (`GET /jobs` list vs `GET /jobs/:id` detail) — defensively tries
  /// the plain string field first (e.g. `industryName`), then a
  /// nested object's `name` (e.g. `industry: { name }`).
  static String? _relationName(Map<String, dynamic> json, String flatKey,
      String nestedKey) {
    final flat = json[flatKey];
    if (flat is String && flat.isNotEmpty) return flat;
    final nested = json[nestedKey];
    if (nested is Map) return nested['name']?.toString();
    return null;
  }

  /// Reads a list of master-data relations (skills/benefits/assets/
  /// qualifications). Confirmed real shape (raw payload dump,
  /// 2026-09-11): each item is a join row like
  /// `{ skillId, skill: { id, name, isActive } }` — the display name
  /// is nested one level under [nestedKey] ('skill'/'asset'/'benefit'/
  /// 'qualification'), NOT a flat `name` on the item itself. Still
  /// checks a flat `name` first in case a different endpoint ever
  /// returns the simpler shape.
  static List<String> _relationNames(
      Map<String, dynamic> json, List<String> keys, String nestedKey) {
    for (final key in keys) {
      final value = json[key];
      if (value is! List || value.isEmpty) continue;
      return value
          .map((e) {
        if (e is String) return e;
        if (e is Map) {
          final flatName = e['name']?.toString();
          if (flatName != null && flatName.isNotEmpty) return flatName;
          final nested = e[nestedKey];
          if (nested is Map) return nested['name']?.toString() ?? '';
        }
        return '';
      })
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  factory JobModel.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    final poster = json['poster'] as Map<String, dynamic>?;
    final recruiter =
        poster?['recruiter'] as Map<String, dynamic>? ??
            json['recruiter'] as Map<String, dynamic>?;

    // Confirmed (raw payload dump, 2026-09-11): `phone` lives on
    // `poster` directly, a SIBLING of the nested `poster.recruiter`
    // object — NOT inside `recruiter` alongside name/email. Falls back
    // to `recruiter?['phone']` in case the backend ever nests it there
    // instead for some jobs.
    final recruiterPhone =
        poster?['phone']?.toString() ?? recruiter?['phone']?.toString();

    final city = location?['city'];
    final locality = location?['locality'];
    final state = location?['state'];

    // Pick whichever wage pair is actually filled — daily first (most
    // common for this app's blue/grey-collar audience), then monthly,
    // then yearly. Backend guarantees at least one pair is complete.
    int? salaryMin;
    int? salaryMax;
    String? wagePeriod;
    for (final entry in [
      ('daily', json['dailyWageMin'], json['dailyWageMax']),
      ('monthly', json['monthlyWageMin'], json['monthlyWageMax']),
      ('yearly', json['yearlyWageMin'], json['yearlyWageMax']),
    ]) {
      if (entry.$2 != null && entry.$3 != null) {
        wagePeriod = entry.$1;
        salaryMin = entry.$2 as int?;
        salaryMax = entry.$3 as int?;
        break;
      }
    }

    final highlightsRaw = json['highlights'];
    final highlights = highlightsRaw is List
        ? highlightsRaw.map((e) => e.toString()).toList()
        : <String>[];

    // The real "Responsibilities" bullet list — a separate field from
    // `highlights` (confirmed from a raw job payload dump on
    // 2026-09-11: `highlights` is a free-text notes field like "This
    // job for only male candidates", NOT the bullet points).
    final responsibilitiesRaw = json['responsibilities'];
    final responsibilities = responsibilitiesRaw is List
        ? responsibilitiesRaw.map((e) => e.toString()).toList()
        : <String>[];

    final languagesRaw = json['languages'];
    final languages = languagesRaw is List
        ? languagesRaw
        .map((e) => e is String ? e : (e as Map)['name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList()
        : <String>[];

    return JobModel(
      id: json['id']?.toString() ?? '',
      title: json['jobRoleName']?.toString() ??
          (json['jobRole'] as Map<String, dynamic>?)?['name']?.toString() ??
          'Untitled role',
      companyName: recruiter?['name']?.toString() ?? 'Unknown Company',
      status: json['status']?.toString(),

      locationName: [locality, city, state]
          .where((e) => e != null && e.toString().isNotEmpty)
          .join(', '),

      salaryMin: salaryMin,
      salaryMax: salaryMax,
      wagePeriod: wagePeriod,

      headcountRequired: json['headcountRequired'] is int
          ? json['headcountRequired'] as int
          : int.tryParse(json['headcountRequired']?.toString() ?? ''),

      gender: json['gender']?.toString(),
      workingDays: json['workingDays']?.toString(),
      freshersOnly: json['freshersOnly'] == true,
      workingStatus: json['workingStatus']?.toString(),

      minExperienceMonths: json['minExperienceMonths'] is int
          ? json['minExperienceMonths'] as int
          : int.tryParse(json['minExperienceMonths']?.toString() ?? ''),
      maxExperienceMonths: json['maxExperienceMonths'] is int
          ? json['maxExperienceMonths'] as int
          : int.tryParse(json['maxExperienceMonths']?.toString() ?? ''),

      industryName: _relationName(json, 'industryName', 'industry'),
      functionName: _relationName(json, 'functionName', 'function'),

      highlights: highlights,
      responsibilities: responsibilities,
      skillNames: _relationNames(json, ['skills', 'skillNames'], 'skill'),
      benefitNames:
      _relationNames(json, ['benefits', 'benefitNames'], 'benefit'),
      assetNames: _relationNames(json, ['assets', 'assetNames'], 'asset'),
      qualificationNames: _relationNames(
          json, ['qualifications', 'qualificationNames'], 'qualification'),
      languages: languages,

      postedAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,

      // `description` IS a real confirmed field (raw payload dump,
      // 2026-09-11) — read directly, no longer purely defensive.
      description: (json['description'] as Object?)?.toString(),
      recruiterEmail: recruiter?['email']?.toString(),
      recruiterPhone: recruiterPhone,

      // Real fields confirmed from the raw payload dump — 'full_time'
      // | 'part_time' | 'contract' and 'day' | 'night' | 'rotational'.
      // `Job.jobTypeLabel`/`shiftTypeLabel` turn these into display text.
      jobType: json['jobType']?.toString(),
      shiftType: json['shiftType']?.toString(),
    );
  }
}
