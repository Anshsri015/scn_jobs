import 'package:dio/dio.dart';

import 'package:scn_jobs/core/error/api_failure.dart';
import 'package:scn_jobs/data/datasources/profile_remote_datasource.dart';
import 'package:scn_jobs/data/models/education_model.dart';
import 'package:scn_jobs/domain/entities/education.dart';
import 'package:scn_jobs/domain/repositories/education_repository.dart';

/// ⚠️ There's no `GET /worker/education` in the API doc — education
/// records only come back embedded in `GET /worker/profile`'s
/// response. [list] fetches the whole profile just to read its
/// `.education` back off — one extra profile fetch per list-education
/// call. Acceptable for now (`EducationListScreen` only calls this
/// once per screen visit, same as the stub it replaces); worth
/// revisiting with a cached/shared profile fetch if this screen starts
/// getting called more often than that.
class EducationRepositoryImpl implements EducationRepository {
  EducationRepositoryImpl(this._remoteDataSource);

  final ProfileRemoteDataSource _remoteDataSource;

  @override
  Future<List<Education>> list() async {
    final profile = await _remoteDataSource.getProfile();
    return profile.education;
  }

  @override
  Future<Education> add(Education education) {
    return _run(() => _remoteDataSource.addEducation(_toModel(education)));
  }

  @override
  Future<Education> update(Education education) {
    return _run(() => _remoteDataSource.updateEducation(_toModel(education)));
  }

  @override
  Future<void> remove(String educationId) {
    return _remoteDataSource.removeEducation(educationId);
  }

  // ErrorInterceptor attaches the mapped ApiFailure to `DioException.error`
  // but doesn't itself throw ApiFailure — without unwrapping it here, a
  // caller's `catch (e) { e is ApiFailure }` never matches, and backend
  // messages like "institute is required for this qualification level"
  // never reach the UI. Same pattern as `AuthRepositoryImpl.currentUser()`.
  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final failure = e.error;
      if (failure is ApiFailure) throw failure;
      rethrow;
    }
  }

  EducationModel _toModel(Education education) {
    return EducationModel(
      id: education.id,
      level: education.level,
      qualificationId: education.qualificationId,
      qualificationName: education.qualificationName,
      institute: education.institute,
    );
  }
}
