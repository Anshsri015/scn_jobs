import 'package:scn_jobs/domain/entities/experience.dart';
import 'package:scn_jobs/domain/repositories/experience_repository.dart';

class UpdateExperienceUseCase {
  const UpdateExperienceUseCase(this._repository);
  final ExperienceRepository _repository;

  Future<Experience> call(Experience experience) =>
      _repository.update(experience);
}
