import 'package:scn_jobs/domain/entities/master_data.dart';

/// Cache-aside contract — implementations (Day 11's pending data layer)
/// are expected to check Isar first, fall back to the remote API on a
/// cache miss, and populate Isar on a successful fetch. That policy
/// lives in `MasterRepositoryImpl`, not here; this interface only
/// promises "you'll get the list back", not how.
abstract class MasterRepository {
  /// Step 1 of the location cascade — `GET /master/locations/states`.
  Future<List<String>> getLocationStates();

  /// Step 2 — `GET /master/locations/states/:state/cities`, scoped to
  /// [state] (URL-encoded by the datasource).
  Future<List<String>> getLocationCities(String state);

  /// Step 3 — `GET /master/locations/:city/localities?state=`. Only
  /// this tier returns a real id (see `LocationItem`'s doc comment).
  /// [state] is always passed since some city names repeat across
  /// states (e.g. "Ambala" in both Haryana and Punjab).
  Future<List<LocationItem>> getLocationLocalities({
    required String state,
    required String city,
  });

  Future<List<IndustryItem>> getIndustries();
  Future<List<SkillItem>> getSkills();
  Future<List<LanguageItem>> getLanguages();
  Future<List<QualificationItem>> getQualifications();
  Future<List<AssetItem>> getAssets();
  Future<List<JobFunctionItem>> getJobFunctions();

  /// [jobFunctionId] filters to roles under that function; null returns
  /// every role (only meaningful if the backend's job roles turn out to
  /// be unscoped — see `JobRoleItem`'s doc comment).
  Future<List<JobRoleItem>> getJobRoles({String? jobFunctionId});
}

