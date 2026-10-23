import 'package:scn_jobs/domain/entities/master_data.dart';

/// One row from the legacy flat `GET /master/locations` endpoint —
/// `{ id, state, city, locality, isActive }`. Confirmed real shape
/// (Day 12 follow-up): the documented cascade routes
/// (`/master/locations/states`, `/states/:state/cities`,
/// `/:city/localities`) all 404 on this deployment, so
/// `MasterRepositoryImpl` fetches this flat list once and derives
/// states/cities/localities from it client-side. Kept separate from
/// `LocationItem` (the entity) since a raw row isn't a "location
/// item" by itself — it's the source data multiple derived
/// `LocationItem`s get built from.
class LocationRecordModel {
  const LocationRecordModel({
    required this.id,
    required this.state,
    required this.city,
    required this.locality,
    required this.isActive,
  });

  final String id;
  final String state;
  final String city;
  final String locality;
  final bool isActive;

  factory LocationRecordModel.fromJson(Map<String, dynamic> json) {
    return LocationRecordModel(
      id: json['id']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      locality: json['locality']?.toString() ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// Every `/master/*` list endpoint (locations, industries, skills,
/// languages, qualifications, functions, job-roles) reduces to at
/// least `{ id, name }` — matches `MasterDataItem`'s shared base. Each
/// class below is a plain JSON parser, not a subclass of its entity —
/// `LocationItem`/`IndustryItem`/etc. in `master_data.dart` are
/// declared `final class`, which Dart only allows extending from
/// within the same file. That's the whole reason these are static
/// `fromJson` factories that *construct and return* the entity,
/// instead of the `extends`-based `JobModel`-style pattern used
/// elsewhere in `data/models/` (`Job` isn't `final`, so that pattern
/// works there but not here).
class LocationItemModel {
  /// Parses one entry from `GET /master/locations/:city/localities`,
  /// e.g. `{ id: 4821, state: "Uttar Pradesh", city: "Noida",
  /// locality: "Sector 62" }` — confirmed shape per the Master Data
  /// API doc. Note the display name comes from `locality`, not
  /// `name`; `id` here is a real number, kept as a `String` like
  /// every other `MasterDataItem.id` and converted back to `int` only
  /// at submit time (`ProfileRepositoryImpl._asId`).
  static LocationItem fromJson(Map<String, dynamic> json) {
    return LocationItem(
      id: json['id']?.toString() ?? '',
      name: json['locality']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      stateName: json['state']?.toString() ?? '',
    );
  }
}

class IndustryItemModel {
  static IndustryItem fromJson(Map<String, dynamic> json) {
    return IndustryItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class SkillItemModel {
  static SkillItem fromJson(Map<String, dynamic> json) {
    return SkillItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class LanguageItemModel {
  static LanguageItem fromJson(Map<String, dynamic> json) {
    return LanguageItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class QualificationItemModel {
  static QualificationItem fromJson(Map<String, dynamic> json) {
    return QualificationItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      level: json['level']?.toString() ?? 'ANY',
    );
  }
}

class AssetItemModel {
  static AssetItem fromJson(Map<String, dynamic> json) {
    return AssetItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class JobFunctionItemModel {
  static JobFunctionItem fromJson(Map<String, dynamic> json) {
    return JobFunctionItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class JobRoleItemModel {
  static JobRoleItem fromJson(Map<String, dynamic> json) {
    return JobRoleItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      jobFunctionId:
      json['functionId']?.toString() ?? json['jobFunctionId']?.toString(),
    );
  }
}
