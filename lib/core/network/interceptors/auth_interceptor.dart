import 'package:dio/dio.dart';
import 'package:scn_jobs/core/storage/secure_storage_service.dart';

/// Attaches Authorization header from securely stored token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.secureStorageService);
  final SecureStorageService secureStorageService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorageService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
