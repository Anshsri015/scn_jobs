import 'package:scn_jobs/domain/repositories/experience_repository.dart';

class RemoveExperienceUseCase {
  const RemoveExperienceUseCase(this._repository);
  final ExperienceRepository _repository;

  Future<void> call(String experienceId) => _repository.remove(experienceId);
}
