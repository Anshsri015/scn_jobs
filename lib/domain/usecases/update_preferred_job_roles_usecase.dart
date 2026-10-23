import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

class UpdatePreferredJobRolesUseCase {
  const UpdatePreferredJobRolesUseCase(this._repository);
  final ProfileRepository _repository;

  Future<WorkerProfile> call(List<String> jobRoleIds) =>
      _repository.updatePreferredJobRoles(jobRoleIds);
}
