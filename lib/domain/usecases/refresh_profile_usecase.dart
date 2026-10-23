import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

/// Re-fetches the profile from the backend — called once profile-setup
/// finishes, so `isComplete` reflects whatever completeness rule the
/// backend applies (education/experience/preferences all saved, etc.)
/// rather than the client guessing at it.
class RefreshProfileUseCase {
  const RefreshProfileUseCase(this._repository);
  final ProfileRepository _repository;

  Future<WorkerProfile> call() => _repository.getProfile();
}
