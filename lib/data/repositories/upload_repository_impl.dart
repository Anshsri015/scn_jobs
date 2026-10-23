import 'package:flutter/material.dart';

import 'package:scn_jobs/data/datasources/upload_remote_datasource.dart';
import 'package:scn_jobs/domain/entities/upload_cancel_token.dart';
import 'package:scn_jobs/domain/entities/upload_progress.dart';
import 'package:scn_jobs/domain/repositories/upload_repository.dart';

class UploadRepositoryImpl implements UploadRepository {
  UploadRepositoryImpl({required UploadRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final UploadRemoteDataSource _remoteDataSource;

  @override
  Future<String> uploadResume({
    required BuildContext context,
    required String filePath,
    required String fileName,
    void Function(UploadProgress progress)? onProgress,
    UploadCancelToken? cancelToken,
  }) {
    return _remoteDataSource.uploadResume(
      context: context,
      filePath: filePath,
      fileName: fileName,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<String> uploadPhoto({
    required BuildContext context,
    required String filePath,
    required String fileName,
    void Function(UploadProgress progress)? onProgress,
    UploadCancelToken? cancelToken,
  }) {
    return _remoteDataSource.uploadPhoto(
      context: context,
      filePath: filePath,
      fileName: fileName,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}
