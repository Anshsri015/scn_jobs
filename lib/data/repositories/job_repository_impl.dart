import 'package:scn_jobs/core/network/pagination.dart';
import 'package:scn_jobs/data/datasources/jobs_remote_datasource.dart';
import 'package:scn_jobs/domain/entities/job.dart';
import 'package:scn_jobs/domain/repositories/job_repository.dart';

class JobRepositoryImpl implements JobRepository {
  JobRepositoryImpl(this._remoteDataSource);

  final JobsRemoteDataSource _remoteDataSource;

  @override
  Future<Page<Job>> getJobs({
    String? cursor,
    String? searchQuery,
    List<String>? locationIds,
    List<String>? industryIds,
  }) async {
    final jobs = await _remoteDataSource.fetchJobs();

    return Page<Job>(
      items: jobs,
      hasMore: false,
    );
  }

  @override
  Future<Job> getJobDetail(String jobId) async {
    return _remoteDataSource.fetchJobDetail(jobId);
  }
}