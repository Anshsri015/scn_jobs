import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:scn_jobs/core/utils/logger.dart';
import 'package:scn_jobs/data/models/master_data_model.dart';
import 'package:scn_jobs/domain/entities/master_data.dart';

/// Same success/data unwrap pattern as `JobsRemoteDataSource` — every
/// endpoint here returns `{ success, data, message? }`. All
/// `/master/*` routes require a Bearer token (any logged-in role) —
/// `dioProvider`'s `AuthInterceptor` already attaches it, nothing
/// extra needed here.
class MasterRemoteDataSource {
  MasterRemoteDataSource(this._dio);

  final Dio _dio;

  /// ⚠️ `locations/cities` (and possibly other `/master/*` lists) came
  /// back as a 200 with a real body, but the app still showed "Couldn't
  /// load locations" — meaning parsing crashed *after* a successful
  /// HTTP response. The likely cause: this used to do
  /// `Map<String, dynamic>.from(e as Map)` unconditionally, which
  /// throws the instant one list entry isn't a Map (e.g. the backend
  /// sending cities as plain strings — `["Mumbai", "Pune"]` — rather
  /// than `[{id, name}, ...]`). One bad/differently-shaped entry used
  /// to take down the entire list. Now: a String entry becomes
  /// `{id: value, name: value}` (good enough for a picker — the
  /// backend clearly has no separate id for a bare string anyway), and
  /// anything else unparseable is skipped and logged rather than
  /// thrown, so one odd row doesn't blank the whole screen.
  List<Map<String, dynamic>> _unwrapList(
      Response<Map<String, dynamic>> response,
      String endpoint,
      ) {
    final data = response.data;
    if (data == null || data['success'] != true) {
      throw Exception('Unable to reach $endpoint');
    }
    final payload = data['data'];
    if (payload is! List) {
      throw Exception('Invalid response shape from $endpoint');
    }

    final result = <Map<String, dynamic>>[];
    for (final e in payload) {
      if (e is Map) {
        result.add(Map<String, dynamic>.from(e));
      } else if (e is String) {
        result.add({'id': e, 'name': e});
      } else {
        AppLogger.e(
          '$endpoint returned an unparseable list entry: $e (${e.runtimeType})',
        );
      }
    }
    return result;
  }

  /// ✅ CONFIRMED (Day 12 follow-up, via direct Postman testing) —
  /// the documented cascade routes (`/master/locations/states`,
  /// `/master/locations/states/:state/cities`,
  /// `/master/locations/:city/localities`) all 404 ("Cannot GET") on
  /// this deployment. Only this legacy flat endpoint works, and it
  /// returns every location row in one response — `{ id, state, city,
  /// locality, isActive }`, with a real numeric `id` per row (unlike
  /// the cascade routes' cities/states tiers, which only ever
  /// returned bare name strings with no id to submit). Fetched once
  /// and cached by `MasterRepositoryImpl`; states/cities/localities
  /// are all derived from this single list client-side.
  Future<List<LocationRecordModel>> fetchAllLocations() async {
    final response = await _dio.get<Map<String, dynamic>>('/master/locations');
    return _unwrapList(response, '/master/locations')
        .map(LocationRecordModel.fromJson)
        .toList();
  }

  Future<List<IndustryItem>> fetchIndustries() async {
    final response = await _dio.get<Map<String, dynamic>>('/master/industries');
    return _unwrapList(response, '/master/industries')
        .map(IndustryItemModel.fromJson)
        .toList();
  }

  Future<List<SkillItem>> fetchSkills() async {
    final response = await _dio.get<Map<String, dynamic>>('/master/skills');
    return _unwrapList(response, '/master/skills')
        .map(SkillItemModel.fromJson)
        .toList();
  }

  Future<List<LanguageItem>> fetchLanguages() async {
    final response = await _dio.get<Map<String, dynamic>>('/master/languages');
    return _unwrapList(response, '/master/languages')
        .map(LanguageItemModel.fromJson)
        .toList();
  }

  /// ⚠️ Response shape changed (post-revamp API doc, Section 2):
  /// `GET /master/qualifications` now returns `data` as an object
  /// grouped by level (`{ TEN: [...], TWELVE: [...], DIPLOMA: [...],
  /// GRADUATE: [...], POST_GRADUATE: [...], ANY: [...] }`), not a
  /// flat array — `_unwrapList` would throw "Invalid response shape"
  /// on this. Flattened here into one list (each item keeps its
  /// `level`) so `qualificationsProvider` and every screen consuming
  /// it stay unchanged; the education form filters by `level` client
  /// -side once the worker picks TEN/TWELVE/Diploma/etc.
  Future<List<QualificationItem>> fetchQualifications() async {
    final response =
    await _dio.get<Map<String, dynamic>>('/master/qualifications');
    final data = response.data;
    if (data == null || data['success'] != true) {
      throw Exception('Unable to reach /master/qualifications');
    }
    final payload = data['data'];
    if (payload is! Map) {
      throw Exception('Invalid response shape from /master/qualifications');
    }
    final result = <QualificationItem>[];
    // ⚠️ BUG FOUND: this used to do `for (final entry in payload.values)`
    // — that only walks the *lists*, throwing away the map key (TEN /
    // TWELVE / DIPLOMA / GRADUATE / POST_GRADUATE / ANY) each list sits
    // under. Individual qualification rows inside those lists don't
    // carry their own `level` field — the grouping key IS the level —
    // so `QualificationItemModel.fromJson` had nothing to read and
    // silently fell back to its `'ANY'` default for *every single
    // qualification*, no matter which group it actually came from.
    //
    // Effect: `EducationFormScreen`'s dropdown filters
    // `quals.where((q) => q.level == level)` — with every item's level
    // stuck at 'ANY', this filter returned an empty list for TEN /
    // TWELVE / DIPLOMA / GRADUATE / POST_GRADUATE, so the "Qualification"
    // dropdown was always empty except when the worker picked "Other /
    // Certification" (level == 'ANY') themselves. That's why picking
    // "Graduate" showed no qualifications to choose from, forcing a
    // fallback to typing free text under "Other / Certification" —
    // which then saves with `level: 'ANY'`, so the entry displays as
    // "Other / Certification" instead of "Graduate" even though the
    // college name was entered correctly.
    //
    // Fix: iterate `payload.entries` instead, and inject the group key
    // as `level` on each item before parsing (unless the row already
    // has an explicit `level` of its own, in which case that wins).
    for (final entry in payload.entries) {
      final groupLevel = entry.key.toString();
      final items = entry.value;
      if (items is! List) continue;
      for (final e in items) {
        if (e is Map) {
          final map = Map<String, dynamic>.from(e);
          map['level'] ??= groupLevel;
          result.add(QualificationItemModel.fromJson(map));
        }
      }
    }
    // TEMP DEBUG — remove once confirmed fixed. Shows how many
    // qualifications ended up under each level after the fix; if this
    // still prints everything under ANY, the fix isn't taking effect
    // (stale build / provider still cached from before restart).
    final byLevel = <String, int>{};
    for (final q in result) {
      byLevel[q.level] = (byLevel[q.level] ?? 0) + 1;
    }
    if (kDebugMode) {
      debugPrint("=========== /master/qualifications — counts by level ===========");
      debugPrint(byLevel.toString());
      debugPrint("===================================================================");
    }
    return result;
  }

  Future<List<AssetItem>> fetchAssets() async {
    final response = await _dio.get<Map<String, dynamic>>('/master/assets');
    return _unwrapList(response, '/master/assets')
        .map(AssetItemModel.fromJson)
        .toList();
  }

  Future<List<JobFunctionItem>> fetchJobFunctions() async {
    final response = await _dio.get<Map<String, dynamic>>('/master/functions');
    return _unwrapList(response, '/master/functions')
        .map(JobFunctionItemModel.fromJson)
        .toList();
  }

  Future<List<JobRoleItem>> fetchJobRoles({String? jobFunctionId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/master/job-roles',
      queryParameters: jobFunctionId != null
          ? {'function_id': jobFunctionId}
          : null,
    );
    return _unwrapList(response, '/master/job-roles')
        .map(JobRoleItemModel.fromJson)
        .toList();
  }
}

// WHY THIS FILE
// No Isar caching here, unlike `MasterRepository`'s interface doc
// (written back on Day 8, before this datasource existed) which
// describes a cache-aside policy. Skipped for this pass to get master
// data unblocking Education/Skills/Languages/Preferences screens
// fastest — every list here is small and rarely changes, so a plain
// network-only fetch is a reasonable v1. Adding an Isar-backed cache
// later is additive: it slots into `MasterRepositoryImpl` (check Isar
// first, fall back to this datasource on a miss) without this
// datasource or its callers changing.
