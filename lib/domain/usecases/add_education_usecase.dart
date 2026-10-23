import 'package:scn_jobs/domain/entities/education.dart';
import 'package:scn_jobs/domain/repositories/education_repository.dart';

class AddEducationUseCase {
  const AddEducationUseCase(this._repository);
  final EducationRepository _repository;

  Future<Education> call(Education education) => _repository.add(education);
}
