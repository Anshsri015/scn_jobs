import 'package:scn_jobs/core/network/pagination.dart';
import 'package:scn_jobs/data/datasources/applications_remote_datasource.dart';
import 'package:scn_jobs/domain/entities/application.dart';
import 'package:scn_jobs/domain/repositories/application_repository.dart';

/// Replaces `ApplicationRepositoryStub`. `getMyApplications` wraps a
/// flat list in a `Page` the same way `JobRepositoryImpl` does —
/// `/applications/my` has no pagination either, so `hasMore` is always
/// `false` and `cursor` stays null.
class ApplicationRepositoryImpl implements ApplicationRepository {
  ApplicationRepositoryImpl(this._remoteDataSource);

  final ApplicationsRemoteDataSource _remoteDataSource;

  @override
  Future<Application> applyToJob(String jobId, {String? coverNote}) {
    return _remoteDataSource.applyToJob(jobId, coverNote: coverNote);
  }

  @override
  Future<Page<Application>> getMyApplications({String? cursor}) async {
    final applications = await _remoteDataSource.fetchMyApplications();
    return Page<Application>(
      items: applications,
      hasMore: false,
    );
  }

  @override
  Future<Application> getApplicationDetail(String applicationId) {
    return _remoteDataSource.fetchApplicationDetail(applicationId);
  }

  @override
  Future<void> withdrawApplication(String applicationId) {
    return _remoteDataSource.withdrawApplication(applicationId);
  }
}
