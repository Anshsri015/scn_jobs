/// Common shape shared by every master-data category — locations,
/// industries, skills, languages, qualifications, job functions, and
/// job roles all reduce to at least an id + display name from the
/// app's point of view. Categories needing more fields extend this.
///
/// ⚠️ NOT yet verified against the Master Data API doc section — same
/// caveat as `WorkerProfile`/`Education`/`Experience` (Day 8). Field
/// names here are a best-guess scaffold; `MasterDataModel` (data layer,
/// pending) must be checked against real field names before trusting
/// this end-to-end.
sealed class MasterDataItem {
  const MasterDataItem({required this.id, required this.name});
  final String id;
  final String name;
}

/// One entry from `GET /master/locations/:city/localities?state=`.
///
/// This is the *only* tier of the location cascade with a real
/// backend id — `states` (`/master/locations/states`) and `cities`
/// (`/master/locations/states/:state/cities`) are plain string
/// arrays, used only to narrow down which localities to fetch next.
/// `LocationItem.id` is the value that actually gets submitted as
/// `locationId` (job posting, worker preferred locations) — never a
/// state or city name.
final class LocationItem extends MasterDataItem {
  const LocationItem({
    required super.id,
    required super.name,
    required this.city,
    required this.stateName,
  });

  final String city;
  final String stateName;
}

final class IndustryItem extends MasterDataItem {
  const IndustryItem({required super.id, required super.name});
}

final class SkillItem extends MasterDataItem {
  const SkillItem({required super.id, required super.name});
}

final class LanguageItem extends MasterDataItem {
  const LanguageItem({required super.id, required super.name});
}

final class QualificationItem extends MasterDataItem {
  const QualificationItem({
    required super.id,
    required super.name,
    required this.level,
  });

  /// One of TEN | TWELVE | DIPLOMA | GRADUATE | POST_GRADUATE | ANY —
  /// matches `GET /master/qualifications`'s grouping key. Needed so
  /// the education form can filter this flat list back down to just
  /// the level the worker picked.
  final String level;
}

/// One entry from `GET /master/assets` (equipment a job provides or a
/// worker self-reports owning, e.g. "Own Laptop", "Two Wheeler").
final class AssetItem extends MasterDataItem {
  const AssetItem({required super.id, required super.name});
}

final class JobFunctionItem extends MasterDataItem {
  const JobFunctionItem({required super.id, required super.name});
}

/// Job roles are scoped to a job function (e.g. "Delivery Executive"
/// under "Logistics") — [jobFunctionId] is null only if the backend
/// turns out to have flat, unscoped job roles instead.
final class JobRoleItem extends MasterDataItem {
  const JobRoleItem({
    required super.id,
    required super.name,
    this.jobFunctionId,
  });

  final String? jobFunctionId;
}

/// A worker-typed value for any master-data category (skills,
/// industries, job roles, departments, ...) that has no matching
/// entry in the master list yet. There's no "add to master data" API
/// — the typed text itself becomes both the [id] and the [name], so
/// it flows through the exact same `List<String>` update endpoints
/// (`updateSkills`, `updatePreferredIndustries`, ...) as any real
/// master-data id, just as a plain string instead of a backend id.
final class CustomMasterDataItem extends MasterDataItem {
  const CustomMasterDataItem(String value) : super(id: value, name: value);
}

// WHY THIS FILE
// A sealed hierarchy with a shared id+name base means Day 12's picker
// screens (Skills, Languages, Locations, Industries) can share one
// generic "searchable checklist" widget keyed on `MasterDataItem`,
// instead of writing near-identical picker UI once per category.
// Alternative considered: waiting until the Master Data API doc is
// available to write this at all. Rejected for the same reason as Day
// 8's entities — this is pure Dart, no JSON coupling, so it's safe to
// scaffold now; only the data-layer model (pending) needs the real
// field names.
// Pitfall a junior would hit: adding a category-specific field (e.g.
// `stateName` on `LocationItem`) to the base `MasterDataItem` class
// instead of the subtype — that would force every OTHER category
// (skills, languages) to carry a meaningless nullable `stateName` field
// they never use.
