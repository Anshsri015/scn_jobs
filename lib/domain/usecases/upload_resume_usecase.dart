import 'package:flutter/material.dart';

import 'package:scn_jobs/domain/entities/upload_cancel_token.dart';
import 'package:scn_jobs/domain/entities/upload_progress.dart';
import 'package:scn_jobs/domain/repositories/upload_repository.dart';

class UploadResumeUseCase {
  const UploadResumeUseCase(this._repository);
  final UploadRepository _repository;

  Future<String> call({
    required BuildContext context,
    required String filePath,
    required String fileName,
    void Function(UploadProgress progress)? onProgress,
    UploadCancelToken? cancelToken,
  }) {
    return _repository.uploadResume(
      context: context,
      filePath: filePath,
      fileName: fileName,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}
