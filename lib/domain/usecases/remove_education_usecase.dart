import 'package:scn_jobs/domain/repositories/education_repository.dart';

class RemoveEducationUseCase {
  const RemoveEducationUseCase(this._repository);
  final EducationRepository _repository;

  Future<void> call(String educationId) => _repository.remove(educationId);
}
