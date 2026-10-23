import 'package:dio/dio.dart';

import '../models/application_model.dart';

/// Same `{ success, data, message? }` unwrap pattern as
/// `JobsRemoteDataSource` — every `/applications` route follows it too.
class ApplicationsRemoteDataSource {
  ApplicationsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ApplicationModel> applyToJob(String jobId, {String? coverNote}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/applications',
      data: {
        'jobId': jobId,
        if (coverNote != null && coverNote.isNotEmpty) 'coverNote': coverNote,
      },
    );

    final data = response.data;
    if (data == null || data['success'] != true) {
      throw Exception('Unable to submit application');
    }

    final appJson = data['data'];
    if (appJson is! Map) {
      throw Exception('Invalid application response');
    }

    return ApplicationModel.fromJson(Map<String, dynamic>.from(appJson));
  }

  Future<List<ApplicationModel>> fetchMyApplications() async {
    final response = await _dio.get<Map<String, dynamic>>('/applications/my');

    final data = response.data;
    if (data == null || data['success'] != true) {
      throw Exception('Unable to fetch applications');
    }

    final appsJson = data['data'];
    if (appsJson is! List) {
      throw Exception('Invalid applications response');
    }

    return appsJson
        .map((e) => ApplicationModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ApplicationModel> fetchApplicationDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/applications/$id');

    final data = response.data;
    if (data == null || data['success'] != true) {
      throw Exception('Unable to fetch application');
    }

    final appJson = data['data'];
    if (appJson is! Map) {
      throw Exception('Invalid application response');
    }

    return ApplicationModel.fromJson(Map<String, dynamic>.from(appJson));
  }

  /// `DELETE /applications/:id` — withdraws the application. The
  /// backend removes/settles it server-side rather than returning an
  /// updated "withdrawn" status; the caller (repository) just needs
  /// this to complete without throwing.
  Future<void> withdrawApplication(String id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/applications/$id',
    );
    final data = response.data;
    if (data != null && data['success'] == false) {
      throw Exception('Unable to withdraw application');
    }
  }
}
