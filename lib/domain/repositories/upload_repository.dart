import 'package:flutter/material.dart';

import 'package:scn_jobs/domain/entities/upload_cancel_token.dart';
import 'package:scn_jobs/domain/entities/upload_progress.dart';

/// ⚠️ [context] is an intentional, contained exception to Clean
/// Architecture's usual rule that domain/data layers don't know about
/// `BuildContext` — the real implementation
/// (`UploadThingWebViewUploader`) has to mount a `WebView` somewhere
/// in the widget tree to run UploadThing's JS client reliably (see
/// that class's doc comment for the full why). Every other
/// repository in this codebase stays context-free; this one doesn't,
/// specifically and only because of that constraint.
abstract class UploadRepository {
  /// [filePath] is a local file path (from `file_picker`), not a URL.
  /// Returns the uploaded file's public URL on success.
  Future<String> uploadResume({
    required BuildContext context,
    required String filePath,
    required String fileName,
    void Function(UploadProgress progress)? onProgress,
    UploadCancelToken? cancelToken,
  });

  Future<String> uploadPhoto({
    required BuildContext context,
    required String filePath,
    required String fileName,
    void Function(UploadProgress progress)? onProgress,
    UploadCancelToken? cancelToken,
  });
}
