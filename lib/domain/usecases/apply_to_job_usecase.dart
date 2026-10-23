import 'package:scn_jobs/domain/entities/application.dart';
import 'package:scn_jobs/domain/repositories/application_repository.dart';

class ApplyToJobUseCase {
  const ApplyToJobUseCase(this._repository);
  final ApplicationRepository _repository;

  Future<Application> call(String jobId, {String? coverNote}) {
    return _repository.applyToJob(jobId, coverNote: coverNote);
  }
}
