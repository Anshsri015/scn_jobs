import 'package:scn_jobs/core/network/pagination.dart';
import 'package:scn_jobs/domain/entities/job.dart';
import 'package:scn_jobs/domain/repositories/job_repository.dart';

class FetchJobsUseCase {
  const FetchJobsUseCase(this._repository);
  final JobRepository _repository;

  Future<Page<Job>> call({
    String? cursor,
    String? searchQuery,
    List<String>? locationIds,
    List<String>? industryIds,
  }) {
    return _repository.getJobs(
      cursor: cursor,
      searchQuery: searchQuery,
      locationIds: locationIds,
      industryIds: industryIds,
    );
  }
}
