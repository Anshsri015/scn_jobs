import 'package:scn_jobs/domain/entities/experience.dart';
import 'package:scn_jobs/domain/repositories/experience_repository.dart';

class AddExperienceUseCase {
  const AddExperienceUseCase(this._repository);
  final ExperienceRepository _repository;

  Future<Experience> call(Experience experience) => _repository.add(experience);
}
