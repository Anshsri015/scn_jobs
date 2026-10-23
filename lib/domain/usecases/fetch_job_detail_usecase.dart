import 'package:scn_jobs/domain/entities/job.dart';
import 'package:scn_jobs/domain/repositories/job_repository.dart';

class FetchJobDetailUseCase {
  const FetchJobDetailUseCase(this._repository);
  final JobRepository _repository;

  Future<Job> call(String jobId) => _repository.getJobDetail(jobId);
}
