import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/network/dio_provider.dart';
import 'package:scn_jobs/data/datasources/applications_remote_datasource.dart';
import 'package:scn_jobs/data/datasources/jobs_remote_datasource.dart';
import 'package:scn_jobs/data/repositories/application_repository_impl.dart';
import 'package:scn_jobs/data/repositories/job_repository_impl.dart';

import 'package:scn_jobs/domain/repositories/application_repository.dart';
import 'package:scn_jobs/domain/repositories/job_repository.dart';

import 'package:scn_jobs/domain/usecases/apply_to_job_usecase.dart';
import 'package:scn_jobs/domain/usecases/fetch_application_detail_usecase.dart';
import 'package:scn_jobs/domain/usecases/fetch_my_applications_usecase.dart';
import 'package:scn_jobs/domain/usecases/withdraw_application_usecase.dart';

final jobsRemoteDataSourceProvider = Provider<JobsRemoteDataSource>((ref) {
  return JobsRemoteDataSource(
    ref.watch(dioProvider),
  );
});

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepositoryImpl(
    ref.watch(jobsRemoteDataSourceProvider),
  );
});

final applicationsRemoteDataSourceProvider =
    Provider<ApplicationsRemoteDataSource>((ref) {
  return ApplicationsRemoteDataSource(ref.watch(dioProvider));
});

/// Day 17 — was `ApplicationRepositoryStub` (in-memory fake). Now the
/// real backend-backed implementation.
final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepositoryImpl(
    ref.watch(applicationsRemoteDataSourceProvider),
  );
});

final applyToJobUseCaseProvider = Provider<ApplyToJobUseCase>((ref) {
  return ApplyToJobUseCase(
    ref.watch(applicationRepositoryProvider),
  );
});

final withdrawApplicationUseCaseProvider =
Provider<WithdrawApplicationUseCase>((ref) {
  return WithdrawApplicationUseCase(
    ref.watch(applicationRepositoryProvider),
  );
});

final fetchMyApplicationsUseCaseProvider =
Provider<FetchMyApplicationsUseCase>((ref) {
  return FetchMyApplicationsUseCase(
    ref.watch(applicationRepositoryProvider),
  );
});

final fetchApplicationDetailUseCaseProvider =
Provider<FetchApplicationDetailUseCase>((ref) {
  return FetchApplicationDetailUseCase(
    ref.watch(applicationRepositoryProvider),
  );
});
