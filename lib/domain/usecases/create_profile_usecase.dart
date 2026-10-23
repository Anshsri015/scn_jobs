import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

class CreateProfileUseCase {
  const CreateProfileUseCase(this._repository);
  final ProfileRepository _repository;

  Future<WorkerProfile> call() => _repository.createProfile();
}
