import 'package:dio/dio.dart';

import 'package:scn_jobs/core/error/exceptions.dart';
import 'package:scn_jobs/data/models/notification_model.dart';

class NotificationsRemoteDataSource {
  NotificationsRemoteDataSource(this._dio);

  final Dio _dio;

  /// `GET /notifications` — up to the 50 most recent notifications,
  /// already filtered server-side for the logged-in user's role.
  ///
  /// Same cold-start-tolerant options as `JobsRemoteDataSource` (Render
  /// free tier can take 10-40s to wake) — one patient attempt, no
  /// stacked retries.
  Future<List<NotificationModel>> fetchHistory() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      options: Options(
        sendTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        connectTimeout: const Duration(seconds: 25),
        extra: {'noRetry': true},
      ),
    );

    final body = response.data;
    if (body == null || body['success'] != true) {
      throw const ServerException('Unable to fetch notifications');
    }

    final list = body['data'];
    if (list is! List) {
      throw const ServerException('Invalid notifications response');
    }

    final result = <NotificationModel>[];
    for (final item in list) {
      if (item is! Map) continue;
      try {
        result.add(
          NotificationModel.fromJson(Map<String, dynamic>.from(item)),
        );
      } on FormatException {
        // One malformed row must not hide the rest of the list.
        continue;
      }
    }
    return result;
  }
}
