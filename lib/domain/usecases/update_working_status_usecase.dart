import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

class UpdateWorkingStatusUseCase {
  const UpdateWorkingStatusUseCase(this._repository);
  final ProfileRepository _repository;

  Future<WorkerProfile> call({
    bool? isFresher,
    String? workingStatus,
    int? noticePeriodDays,
  }) {
    return _repository.updateWorkingStatus(
      isFresher: isFresher,
      workingStatus: workingStatus,
      noticePeriodDays: noticePeriodDays,
    );
  }
}
