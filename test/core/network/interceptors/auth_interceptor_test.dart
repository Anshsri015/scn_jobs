import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:scn_jobs/core/network/interceptors/auth_interceptor.dart';
import 'package:scn_jobs/core/storage/secure_storage_service.dart';

import 'auth_interceptor_test.mocks.dart';

@GenerateMocks([SecureStorageService])
void main() {
  late MockSecureStorageService mockSecureStorageService;
  late AuthInterceptor authInterceptor;

  setUp(() {
    mockSecureStorageService = MockSecureStorageService();
    authInterceptor = AuthInterceptor(mockSecureStorageService);
  });

  test('adds Authorization header when token exists', () async {
    when(mockSecureStorageService.getAccessToken())
        .thenAnswer((_) async => 'test_token_123');

    final options = RequestOptions(path: '/test');
    final handler = RequestInterceptorHandler();

    authInterceptor.onRequest(options, handler);
    await handler.future;

    expect(options.headers['Authorization'], 'Bearer test_token_123');
  });

  test('does not add Authorization header when token is null', () async {
    when(mockSecureStorageService.getAccessToken())
        .thenAnswer((_) async => null);

    final options = RequestOptions(path: '/test');
    final handler = RequestInterceptorHandler();

    authInterceptor.onRequest(options, handler);
    await handler.future;

    expect(options.headers.containsKey('Authorization'), false);
  });
}
