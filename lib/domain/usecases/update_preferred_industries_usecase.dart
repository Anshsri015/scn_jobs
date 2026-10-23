import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

class UpdatePreferredIndustriesUseCase {
  const UpdatePreferredIndustriesUseCase(this._repository);
  final ProfileRepository _repository;

  Future<WorkerProfile> call(List<String> industryIds) =>
      _repository.updatePreferredIndustries(industryIds);
}
