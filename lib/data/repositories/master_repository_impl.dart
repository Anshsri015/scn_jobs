import 'package:scn_jobs/data/datasources/master_remote_datasource.dart';
import 'package:scn_jobs/data/models/master_data_model.dart';
import 'package:scn_jobs/domain/entities/master_data.dart';
import 'package:scn_jobs/domain/repositories/master_repository.dart';

/// ✅ Day 12 follow-up — the documented 3-step location cascade
/// (`states` -> `states/:state/cities` -> `:city/localities`) 404s on
/// this deployment; only the legacy flat `/master/locations` endpoint
/// works. This fetches that flat list ONCE (cached on `this` for the
/// lifetime of `masterRepositoryProvider`, which isn't autoDispose —
/// see `master_providers.dart`) and derives every location query from
/// it in-memory, so `CascadingLocationPicker` and everything else
/// downstream keeps working against the same `MasterRepository`
/// interface without knowing the cascade routes don't exist.
class MasterRepositoryImpl implements MasterRepository {
  MasterRepositoryImpl(this._remoteDataSource);

  final MasterRemoteDataSource _remoteDataSource;

  /// In-flight/completed fetch, memoized so concurrent callers (e.g.
  /// the states dropdown and a stale in-progress cities lookup) share
  /// one network call instead of each firing their own.
  Future<List<LocationRecordModel>>? _allLocationsFuture;

  Future<List<LocationRecordModel>> _allLocations() {
    return _allLocationsFuture ??= _remoteDataSource.fetchAllLocations();
  }

  @override
  Future<List<String>> getLocationStates() async {
    final records = await _allLocations();
    final states = records
        .where((r) => r.isActive)
        .map((r) => r.state)
        .toSet()
        .toList()
      ..sort();
    return states;
  }

  @override
  Future<List<String>> getLocationCities(String state) async {
    final records = await _allLocations();
    final cities = records
        .where((r) => r.isActive && r.state == state)
        .map((r) => r.city)
        .toSet()
        .toList()
      ..sort();
    return cities;
  }

  @override
  Future<List<LocationItem>> getLocationLocalities({
    required String state,
    required String city,
  }) async {
    final records = await _allLocations();
    return records
        .where((r) => r.isActive && r.state == state && r.city == city)
        .map(
          (r) => LocationItem(
        id: r.id,
        name: r.locality,
        city: r.city,
        stateName: r.state,
      ),
    )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<List<IndustryItem>> getIndustries() {
    return _remoteDataSource.fetchIndustries();
  }

  @override
  Future<List<SkillItem>> getSkills() {
    return _remoteDataSource.fetchSkills();
  }

  @override
  Future<List<LanguageItem>> getLanguages() {
    return _remoteDataSource.fetchLanguages();
  }

  @override
  Future<List<QualificationItem>> getQualifications() {
    return _remoteDataSource.fetchQualifications();
  }

  @override
  Future<List<AssetItem>> getAssets() {
    return _remoteDataSource.fetchAssets();
  }

  @override
  Future<List<JobFunctionItem>> getJobFunctions() {
    return _remoteDataSource.fetchJobFunctions();
  }

  @override
  Future<List<JobRoleItem>> getJobRoles({String? jobFunctionId}) {
    return _remoteDataSource.fetchJobRoles(jobFunctionId: jobFunctionId);
  }
}

