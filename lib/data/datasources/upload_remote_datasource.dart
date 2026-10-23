import 'package:flutter/material.dart';

import 'package:scn_jobs/core/env/app_config.dart';
import 'package:scn_jobs/core/services/uploadthing_webview_uploader.dart';
import 'package:scn_jobs/core/storage/secure_storage_service.dart';
import 'package:scn_jobs/domain/entities/upload_cancel_token.dart';
import 'package:scn_jobs/domain/entities/upload_progress.dart';

/// ✅ Delegates entirely to [UploadThingWebViewUploader] — see that
/// class's doc comment for why. This datasource's job shrinks to just
/// gathering what the uploader needs ([AppConfig.baseUrl], the current
/// bearer token from [SecureStorageService]) and adapting its 0-100
/// progress callback to this app's [UploadProgress] shape.
///
/// [context] flows in from the presentation layer (`ResumeUploadScreen`
/// → `UploadResumeUseCase` → `UploadRepository` → here) — an unusual
/// dependency for a data-layer class, called out explicitly in
/// `UploadRepository`'s doc comment as a deliberate, contained
/// exception to Clean Architecture's normal layering, not an
/// oversight.
class UploadRemoteDataSource {
  const UploadRemoteDataSource(this._uploader);

  final UploadThingWebViewUploader _uploader;

  Future<String> _upload({
    required BuildContext context,
    required String routeSlug,
    required String filePath,
    required String fileName,
    required String contentType,
    void Function(UploadProgress progress)? onProgress,
    UploadCancelToken? cancelToken,
  }) async {
    final token = await SecureStorageService().getAccessToken();
    if (token == null) {
      throw StateError('No access token — user is not logged in.');
    }

    return _uploader.upload(
      context: context,
      baseUrl: AppConfig.baseUrl,
      routeSlug: routeSlug,
      filePath: filePath,
      fileName: fileName,
      contentType: contentType,
      token: token,
      cancelToken: cancelToken,
      onProgress: onProgress == null
          ? null
      // ⚠️ CLAMP: UploadThing's JS client sums per-chunk progress
      // for multi-part uploads and can briefly report >100
      // before settling (seen as "103%" in the UI). Clamp here
      // so this datasource never hands the presentation layer a
      // percentage outside 0-100, regardless of what the JS side
      // sends.
          : (percent) => onProgress(
        UploadProgress(
          bytesSent: percent.clamp(0, 100).round(),
          totalBytes: 100,
        ),
      ),
    );
  }

  Future<String> uploadResume({
    required BuildContext context,
    required String filePath,
    required String fileName,
    void Function(UploadProgress progress)? onProgress,
    UploadCancelToken? cancelToken,
  }) {
    return _upload(
      context: context,
      routeSlug: 'resumeUploader',
      filePath: filePath,
      fileName: fileName,
      contentType: 'application/pdf',
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<String> uploadPhoto({
    required BuildContext context,
    required String filePath,
    required String fileName,
    void Function(UploadProgress progress)? onProgress,
    UploadCancelToken? cancelToken,
  }) {
    // ⚠️ Still unconfirmed — the doc only documents `resumeUploader`.
    // Using the same placeholder slug as before
    // ("profilePhotoUploader") until that's confirmed; this fix
    // targets the resume flow specifically, which IS confirmed.
    return _upload(
      context: context,
      routeSlug: 'profilePhotoUploader',
      filePath: filePath,
      fileName: fileName,
      contentType: 'image/jpeg',
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}

// WHY THIS FILE CHANGED
// Delegates entirely to `UploadThingWebViewUploader` now — see that
// class's doc comment for the full reasoning. `cancelToken` still
// threads through end-to-end (tears down the WebView on cancel; see
// that class's WHY note for what that does and doesn't guarantee).
//
// `percent.clamp(0, 100)` added to the progress adapter — UploadThing's
// onUploadProgress can report slightly over 100% for multi-part
// uploads, and nothing downstream (UploadProgress.percentage,
// ResumeUploadScreen's "% uploaded" text) was guarding against that.