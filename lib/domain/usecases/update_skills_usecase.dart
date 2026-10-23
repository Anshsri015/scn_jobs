import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

class UpdateSkillsUseCase {
  const UpdateSkillsUseCase(this._repository);
  final ProfileRepository _repository;

  Future<WorkerProfile> call(List<String> skillIds) =>
      _repository.updateSkills(skillIds);
}
