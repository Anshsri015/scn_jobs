import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scn_jobs/core/error/api_failure.dart';
import 'package:scn_jobs/core/network/interceptors/error_interceptor.dart';

void main() {
  late ErrorInterceptor errorInterceptor;

  setUp(() {
    errorInterceptor = ErrorInterceptor();
  });

  Future<ApiFailure> captureFailure(DioException dioException) async {
    final handler = ErrorInterceptorHandler();
    errorInterceptor.onError(dioException, handler);
    try {
      await handler.future;
      fail('Expected handler.future to throw');
    } catch (e) {
      final DioException resolvedException;
      if (e is DioException) {
        resolvedException = e;
      } else {
        // Some dio versions throw the wrapping InterceptorState instead
        // of the raw DioException — unwrap its `.data` field.
        resolvedException = (e as dynamic).data as DioException;
      }
      return resolvedException.error! as ApiFailure;
    }
  }

  test('maps connectionTimeout to NetworkFailure with timeout message',
      () async {
    final requestOptions = RequestOptions(path: '/test');
    final dioException = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.connectionTimeout,
    );

    final failure = await captureFailure(dioException);

    expect(failure, isA<NetworkFailure>());
    expect(failure.message, contains('timed out'));
  });

  test('maps badResponse 404 to ServerFailure with statusCode', () async {
    final requestOptions = RequestOptions(path: '/test');
    final response = Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: 404,
      data: {'message': 'Not found'},
    );
    final dioException = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badResponse,
      response: response,
    );

    final failure = await captureFailure(dioException) as ServerFailure;

    expect(failure.statusCode, 404);
    expect(failure.message, 'Not found');
  });

  test('maps badResponse 401 to UnauthorizedFailure', () async {
    final requestOptions = RequestOptions(path: '/test');
    final response = Response<void>(
      requestOptions: requestOptions,
      statusCode: 401,
    );
    final dioException = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badResponse,
      response: response,
    );

    final failure = await captureFailure(dioException);

    expect(failure, isA<UnauthorizedFailure>());
  });
}
