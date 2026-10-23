import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scn_jobs/data/datasources/upload_remote_datasource.dart';
import 'package:scn_jobs/data/repositories/upload_repository_impl.dart';
import 'package:scn_jobs/domain/entities/upload_cancel_token.dart';
import 'package:scn_jobs/domain/entities/upload_progress.dart';

class MockUploadRemoteDataSource extends Mock
    implements UploadRemoteDataSource {}

void main() {
  late MockUploadRemoteDataSource mockDataSource;
  late UploadRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockUploadRemoteDataSource();
    repository = UploadRepositoryImpl(remoteDataSource: mockDataSource);
  });

  group('uploadResume', () {
    test('forwards to the datasource and returns the resulting URL', () async {
      when(
        () => mockDataSource.uploadResume(
          filePath: any(named: 'filePath'),
          fileName: any(named: 'fileName'),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => 'https://cdn.scnjobs.in/resumes/abc.pdf');

      final result = await repository.uploadResume(
        filePath: '/tmp/resume.pdf',
        fileName: 'resume.pdf',
      );

      expect(result, 'https://cdn.scnjobs.in/resumes/abc.pdf');
      verify(
        () => mockDataSource.uploadResume(
          filePath: '/tmp/resume.pdf',
          fileName: 'resume.pdf',
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });

    test('propagates progress callbacks from the datasource', () async {
      UploadProgress? captured;
      when(
        () => mockDataSource.uploadResume(
          filePath: any(named: 'filePath'),
          fileName: any(named: 'fileName'),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress = invocation.namedArguments[#onProgress] as void
            Function(UploadProgress)?;
        onProgress?.call(const UploadProgress(bytesSent: 50, totalBytes: 100));
        return 'https://cdn.scnjobs.in/resumes/abc.pdf';
      });

      await repository.uploadResume(
        filePath: '/tmp/resume.pdf',
        fileName: 'resume.pdf',
        onProgress: (p) => captured = p,
      );

      expect(captured?.percentage, 50);
    });

    test('propagates a thrown exception from the datasource unchanged',
        () async {
      when(
        () => mockDataSource.uploadResume(
          filePath: any(named: 'filePath'),
          fileName: any(named: 'fileName'),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(Exception('network down'));

      expect(
        () => repository.uploadResume(
          filePath: '/tmp/resume.pdf',
          fileName: 'resume.pdf',
        ),
        throwsException,
      );
    });
  });

  group('uploadPhoto', () {
    test('forwards to the datasource and returns the resulting URL', () async {
      when(
        () => mockDataSource.uploadPhoto(
          filePath: any(named: 'filePath'),
          fileName: any(named: 'fileName'),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => 'https://cdn.scnjobs.in/photos/abc.jpg');

      final result = await repository.uploadPhoto(
        filePath: '/tmp/photo.jpg',
        fileName: 'photo.jpg',
      );

      expect(result, 'https://cdn.scnjobs.in/photos/abc.jpg');
    });
  });

  test('UploadCancelToken.cancel() notifies listeners exactly once', () {
    var callCount = 0;
    final token = UploadCancelToken();
    token.addListener(() => callCount++);

    token.cancel();
    token.cancel(); // second call must be a no-op

    expect(callCount, 1);
    expect(token.isCancelled, isTrue);
  });
}

// WHY THIS FILE
// UploadRepositoryImpl is a thin passthrough (like AuthRepositoryImpl's
// simpler methods), so these tests mostly confirm the forwarding
// contract holds — the real value is the progress-callback and
// cancel-token tests, since those are the parts most likely to silently
// break in a refactor (e.g. someone "simplifying" _upload() and
// forgetting to wire onSendProgress through).
