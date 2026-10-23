import 'package:scn_jobs/domain/repositories/application_repository.dart';

class WithdrawApplicationUseCase {
  const WithdrawApplicationUseCase(this._repository);
  final ApplicationRepository _repository;

  Future<void> call(String applicationId) =>
      _repository.withdrawApplication(applicationId);
}
