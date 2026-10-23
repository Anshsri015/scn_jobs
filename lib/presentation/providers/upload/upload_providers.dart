import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/services/uploadthing_webview_uploader.dart';
import 'package:scn_jobs/data/datasources/upload_remote_datasource.dart';
import 'package:scn_jobs/data/repositories/upload_repository_impl.dart';
import 'package:scn_jobs/domain/repositories/upload_repository.dart';
import 'package:scn_jobs/domain/usecases/upload_photo_usecase.dart';
import 'package:scn_jobs/domain/usecases/upload_resume_usecase.dart';

/// ✅ No `dioProvider` here anymore — uploads go through
/// `UploadThingWebViewUploader` (real UploadThing JS client running in
/// a hidden `WebView`), not a hand-rolled Dio request. See that
/// class's doc comment for why.
final uploadThingWebViewUploaderProvider =
    Provider<UploadThingWebViewUploader>((ref) {
  return const UploadThingWebViewUploader();
});

final uploadRemoteDataSourceProvider = Provider<UploadRemoteDataSource>((ref) {
  return UploadRemoteDataSource(ref.watch(uploadThingWebViewUploaderProvider));
});

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepositoryImpl(
    remoteDataSource: ref.watch(uploadRemoteDataSourceProvider),
  );
});

final uploadResumeUseCaseProvider = Provider<UploadResumeUseCase>((ref) {
  return UploadResumeUseCase(ref.watch(uploadRepositoryProvider));
});

final uploadPhotoUseCaseProvider = Provider<UploadPhotoUseCase>((ref) {
  return UploadPhotoUseCase(ref.watch(uploadRepositoryProvider));
});
