import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:scn_jobs/data/models/education_model.dart';
import 'package:scn_jobs/data/models/experience_model.dart';
import 'package:scn_jobs/data/models/worker_profile_model.dart';

/// Same success/data unwrap pattern as `JobsRemoteDataSource` — every
/// endpoint here returns `{ success, data, message? }`.
class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _unwrapMap(
      Response<Map<String, dynamic>> response,
      String endpoint,
      ) {
    final data = response.data;
    if (data == null || data['success'] != true) {
      throw Exception('Unable to reach $endpoint');
    }
    final payload = data['data'];
    if (payload is! Map) {
      throw Exception('Invalid response shape from $endpoint');
    }
    return Map<String, dynamic>.from(payload);
  }

  // --- Profile ---------------------------------------------------------

  /// Creates a blank profile for the logged-in worker. Called once,
  /// right after verify-otp/login (`CreateProfileScreen`).
  ///
  /// The backend rejects a second create with `400 { message: "Profile
  /// already exists" }` — this happens for real whenever a worker
  /// re-enters `CreateProfileScreen` (e.g. app killed mid-setup, or the
  /// onboarding-status check says "not done yet" because the profile
  /// is blank, not because it's missing). Rather than surface that as
  /// a failure the UI has no good way to recover from, treat it as the
  /// success case it actually is: fetch and return the existing
  /// profile instead of the newly-"created" one.
  ///
  /// Same cold-start timeout override as `AuthRemoteDataSource.me()` —
  /// for a brand-new worker this is one of the very first calls made
  /// against the API, often before anything else has had a chance to
  /// wake up a sleeping Render free-tier instance (splash's `/auth/me`
  /// warm-up is skipped entirely when there's no saved session yet —
  /// see `AuthRepositoryImpl.currentUser`). Base 15s + the default
  /// retry stacking was timing this out mid-cold-start, so the create
  /// (and the profile-setup PATCH below) appeared to silently fail on
  /// a worker's very first attempt, then succeed the moment they tried
  /// again — by which point the same cold start had already finished.
  Future<WorkerProfileModel> createProfile() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/worker/profile',
        options: Options(
          sendTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 25),
          connectTimeout: const Duration(seconds: 25),
          extra: {'noRetry': true},
        ),
      );
      return WorkerProfileModel.fromJson(
        _unwrapMap(response, '/worker/profile'),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      if (e.response?.statusCode == 400 &&
          message != null &&
          message.toLowerCase().contains('already exists')) {
        return getProfile();
      }
      rethrow;
    }
  }

  Future<WorkerProfileModel> getProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/worker/profile');

    final rawData = response.data?['data'];
    // TEMP DEBUG — education shows "Other/Certification" no matter
    // what level was picked. Printed FIRST, before the big PROFILE
    // RESPONSE dump below — debugPrint's Android throttling was
    // silently dropping every call that came after that big dump, so
    // this never showed up when tried further down. Packed into ONE
    // call too, so throttling can't eat part of it either.
    //
    // kDebugMode-guarded: unguarded, this was dumping the worker's
    // entire profile (name, DOB, gender, location, etc.) to release
    // logcat on every single profile fetch.
    if (kDebugMode) {
      if (rawData is Map) {
        final educationList = rawData['education'];
        if (educationList is List && educationList.isNotEmpty) {
          final first = educationList.first;
          if (first is Map) {
            debugPrint(
              "--- education (raw) --- "
                  "keys: ${first.keys.toList()} | "
                  "level: ${first['level']} | "
                  "qualificationId: ${first['qualificationId']} "
                  "(${first['qualificationId'].runtimeType}) | "
                  "qualification(nested): ${first['qualification']}",
            );
          } else {
            debugPrint("--- education (raw) --- first entry is not a Map: $first (${first.runtimeType})");
          }
        } else {
          debugPrint("--- education (raw) --- education list is empty or missing");
        }
      }

      debugPrint("=========== PROFILE RESPONSE ===========");
      debugPrint(response.data.toString());
      // Same truncation issue as updateProfile()'s temp debug — pull out
      // just the preference fields so they don't get cut off.
      if (rawData is Map) {
        debugPrint("--- preference fields ---");
        debugPrint("skills: ${rawData['skills']}");
        debugPrint("preferredIndustries: ${rawData['preferredIndustries']}");
        debugPrint("preferredJobRoles: ${rawData['preferredJobRoles']}");
        debugPrint("preferredDepartments: ${rawData['preferredDepartments']}");
        debugPrint("preferredLocations: ${rawData['preferredLocations']}");
      }
      debugPrint("=======================================================");
    }

    return WorkerProfileModel.fromJson(
      _unwrapMap(response, '/worker/profile'),
    );
  }
  /// Partial update — [body] should only contain keys the caller
  /// actually wants changed, matching `PATCH /worker/profile`'s
  /// partial-update contract. Building that map is
  /// `ProfileRepositoryImpl`'s job, not this datasource's.
  ///
  /// Same cold-start timeout override as `createProfile()`/
  /// `AuthRemoteDataSource.me()` above — this is the call behind
  /// Personal Details' "Complete Profile" submit, which for a fresh
  /// worker can land on a still-sleeping Render instance with no prior
  /// warm-up call in this session.
  Future<WorkerProfileModel> updateProfile(Map<String, dynamic> body) async {
    // TEMP DEBUG — remove once the Skills/Preferred Industries/Job
    // Roles/Departments "shows None after save" bug is confirmed fixed.
    // kDebugMode-guarded — `body` here is the worker's own edited
    // profile fields (name, DOB, gender, location, photo...), so
    // unguarded this leaked to release logcat on every save.
    if (kDebugMode) {
      debugPrint("=========== PATCH /worker/profile REQUEST ===========");
      debugPrint(body.toString());
    }
    final response = await _dio.patch<Map<String, dynamic>>(
      '/worker/profile',
      data: body,
      options: Options(
        sendTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        connectTimeout: const Duration(seconds: 25),
        extra: {'noRetry': true},
      ),
    );
    // The full response.data.toString() is too long and gets truncated
    // by logcat before it even reaches the preference fields (they sit
    // after `education`/`experience` in the payload) — so instead of
    // printing everything, pull out ONLY the fields we actually need to
    // see, short enough to never get cut off.
    final rawData = response.data?['data'];
    if (kDebugMode && rawData is Map) {
      debugPrint("=========== PATCH /worker/profile — PREFERENCE FIELDS ===========");
      debugPrint("updatedAt: ${rawData['updatedAt']}");
      debugPrint("skills: ${rawData['skills']}");
      debugPrint("preferredIndustries: ${rawData['preferredIndustries']}");
      debugPrint("preferredJobRoles: ${rawData['preferredJobRoles']}");
      debugPrint("preferredDepartments: ${rawData['preferredDepartments']}");
      debugPrint("preferredLocations: ${rawData['preferredLocations']}");
      debugPrint("===================================================================");
    }
    return WorkerProfileModel.fromJson(_unwrapMap(response, '/worker/profile'));
  }

  // --- Education ---------------------------------------------------------

  Future<EducationModel> addEducation(EducationModel education) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/worker/education',
      data: education.toRequestBody(),
    );
    return EducationModel.fromJson(_unwrapMap(response, '/worker/education'));
  }

  Future<EducationModel> updateEducation(EducationModel education) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/worker/education/${education.id}',
      data: education.toRequestBody(),
    );
    return EducationModel.fromJson(_unwrapMap(response, '/worker/education/:id'));
  }

  Future<void> removeEducation(String educationId) async {
    await _dio.delete<void>('/worker/education/$educationId');
  }

  // --- Experience ---------------------------------------------------------

  Future<ExperienceModel> addExperience(ExperienceModel experience) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/worker/experience',
      data: experience.toRequestBody(),
    );
    return ExperienceModel.fromJson(_unwrapMap(response, '/worker/experience'));
  }

  Future<ExperienceModel> updateExperience(ExperienceModel experience) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/worker/experience/${experience.id}',
      data: experience.toRequestBody(),
    );
    return ExperienceModel.fromJson(
      _unwrapMap(response, '/worker/experience/:id'),
    );
  }

  Future<void> removeExperience(String experienceId) async {
    await _dio.delete<void>('/worker/experience/$experienceId');
  }
}

// WHY THIS FILE
// One datasource for profile + education + experience, not three —
// all three live under the same `/worker/*` surface and are read
// together via one `GET /worker/profile` call (see
// `WorkerProfileModel`'s doc comment), so splitting them into separate
// datasource classes would just mean `EducationRemoteDataSource`
// wrapping the exact same `_dio` with no independent lifecycle of its
// own. `ProfileRepositoryImpl`, `EducationRepositoryImpl`, and
// `ExperienceRepositoryImpl` stay as three separate repository classes
// on the domain side, though — that split matches
// `EducationRepository`/`ExperienceRepository`'s existing interfaces
// and is what screens actually depend on.