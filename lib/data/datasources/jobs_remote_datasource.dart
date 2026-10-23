import 'package:dio/dio.dart';

import '../models/job_model.dart';

class JobsRemoteDataSource {
  JobsRemoteDataSource(this._dio);

  final Dio _dio;

  /// Timeout/retry override tuned for the same reason as `GET
  /// /auth/me` (see `AuthRemoteDataSource.me`'s doc comment) — this
  /// backend is hosted on Render's free tier, which spins down after
  /// ~15 minutes idle and can take 10-40s to cold-start back up. Jobs
  /// is usually the very first real data screen a worker hits after
  /// opening the app (post-splash/login), so it's the most likely
  /// place to actually hit a cold start — matches the reported bug
  /// ("bahut dher baad app kholu to job load nahi hoti, bahut time
  /// leti hai").
  ///
  /// Previously this had no override at all, so it used the global
  /// 15s timeout + the global retry interceptor's 2 retries — a cold
  /// start easily blows past 15s, so the first attempt would time out,
  /// wait 1s, try again (another 15s), wait 2s, try a third time
  /// (another 15s): up to ~48s of waiting, and often failing outright
  /// if the cold start took longer than that. One longer, patient
  /// attempt (with retries turned off so they don't stack on top of
  /// it) is both faster in the common case and more likely to
  /// actually succeed.
  Options get _coldStartTolerantOptions => Options(
    sendTimeout: const Duration(seconds: 25),
    receiveTimeout: const Duration(seconds: 25),
    connectTimeout: const Duration(seconds: 25),
    extra: {'noRetry': true},
  );

  Future<List<JobModel>> fetchJobs() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/jobs',
      options: _coldStartTolerantOptions,
    );

    final data = response.data;

    if (data == null) {
      throw Exception('Empty response from /jobs');
    }

    if (data['success'] != true) {
      throw Exception('Unable to fetch jobs');
    }

    final jobsJson = data['data'];

    if (jobsJson is! List) {
      throw Exception('Invalid jobs response');
    }

    return jobsJson
        .map(
          (e) => JobModel.fromJson(
        Map<String, dynamic>.from(e as Map),
      ),
    )
        .toList();
  }

  Future<JobModel> fetchJobDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/jobs/$id',
      options: _coldStartTolerantOptions,
    );

    final data = response.data;

    if (data == null) {
      throw Exception('Empty response');
    }

    if (data['success'] != true) {
      throw Exception('Unable to fetch job');
    }

    final jobJson = data['data'];

    if (jobJson is! Map) {
      throw Exception('Invalid job response');
    }

    return JobModel.fromJson(
      Map<String, dynamic>.from(jobJson),
    );
  }
}