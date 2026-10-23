import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/network/dio_provider.dart';
import 'package:scn_jobs/data/datasources/master_remote_datasource.dart';
import 'package:scn_jobs/data/repositories/master_repository_impl.dart';
import 'package:scn_jobs/domain/entities/master_data.dart';
import 'package:scn_jobs/domain/repositories/master_repository.dart';

final masterRemoteDataSourceProvider =
Provider<MasterRemoteDataSource>((ref) {
  return MasterRemoteDataSource(ref.watch(dioProvider));
});

/// Day 11 landed — constructs the real, backend-backed impl instead of
/// the old in-memory stub. Every provider below only depends on the
/// abstract `MasterRepository`, so nothing else changed when this
/// swapped.
final masterRepositoryProvider = Provider<MasterRepository>((ref) {
  return MasterRepositoryImpl(ref.watch(masterRemoteDataSourceProvider));
});

/// Step 1 of the location cascade — plain state names, fetched once.
final locationStatesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(masterRepositoryProvider).getLocationStates();
});

/// Step 2 — cities scoped to a state. `.family` keyed by the state
/// name so switching state re-fetches instead of reusing a stale list.
final locationCitiesProvider =
FutureProvider.family<List<String>, String>((ref, state) {
  return ref.watch(masterRepositoryProvider).getLocationCities(state);
});

/// Step 3 — localities scoped to a (state, city) pair. Keyed by a
/// record since `.family` only takes one argument and a locality list
/// depends on both.
final locationLocalitiesProvider = FutureProvider.family<List<LocationItem>,
    ({String state, String city})>((ref, key) {
  return ref
      .watch(masterRepositoryProvider)
      .getLocationLocalities(state: key.state, city: key.city);
});

final industriesProvider = FutureProvider<List<IndustryItem>>((ref) {
  return ref.watch(masterRepositoryProvider).getIndustries();
});

final skillsProvider = FutureProvider<List<SkillItem>>((ref) {
  return ref.watch(masterRepositoryProvider).getSkills();
});

final languagesProvider = FutureProvider<List<LanguageItem>>((ref) {
  return ref.watch(masterRepositoryProvider).getLanguages();
});

/// Watched by `EducationFormScreen` to populate the qualification
/// picker — `Education.qualificationId` must be a real id from this
/// list, never free text (see `Education`'s class doc).
final qualificationsProvider = FutureProvider<List<QualificationItem>>((ref) {
  return ref.watch(masterRepositoryProvider).getQualifications();
});

/// Backs the "Assets & Vehicles" picker on `EditProfileScreen` —
/// `WorkerProfile.assets` is sent/read as a plain list of names (not
/// ids, unlike every other master-data-backed field), matching the
/// API doc's `POST /worker/profile` example (`"assets": ["OwnLaptop",
/// "TwoWheeler"]`). This list is only used to populate the picker's
/// choices; the names themselves are what get sent.
final assetsProvider = FutureProvider<List<AssetItem>>((ref) {
  return ref.watch(masterRepositoryProvider).getAssets();
});

/// Not consumed by any screen yet (no job-function/role picker is
/// built) — exposed now so that screen doesn't need a provider-layer
/// change when it lands, only a UI file.
final jobFunctionsProvider = FutureProvider<List<JobFunctionItem>>((ref) {
  return ref.watch(masterRepositoryProvider).getJobFunctions();
});

final jobRolesProvider =
FutureProvider.family<List<JobRoleItem>, String?>((ref, jobFunctionId) {
  return ref
      .watch(masterRepositoryProvider)
      .getJobRoles(jobFunctionId: jobFunctionId);
});

// WHY THIS FILE
// FutureProvider (not a plain Provider) for each list — master data is
// fetched async, and FutureProvider gives every picker screen a
// ready-made loading/data/error AsyncValue via `ref.watch(...)` without
// each screen writing its own FutureBuilder + repository call.
// `jobRolesProvider` is a `.family` (keyed by `jobFunctionId`) since
// its result depends on an argument the other lists don't take.
