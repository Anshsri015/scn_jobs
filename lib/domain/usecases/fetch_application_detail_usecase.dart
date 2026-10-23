import 'package:scn_jobs/domain/entities/application.dart';
import 'package:scn_jobs/domain/repositories/application_repository.dart';

class FetchApplicationDetailUseCase {
  const FetchApplicationDetailUseCase(this._repository);
  final ApplicationRepository _repository;

  Future<Application> call(String applicationId) =>
      _repository.getApplicationDetail(applicationId);
}
