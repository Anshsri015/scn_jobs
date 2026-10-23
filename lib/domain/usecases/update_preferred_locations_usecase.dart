import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

class UpdatePreferredLocationsUseCase {
  const UpdatePreferredLocationsUseCase(this._repository);
  final ProfileRepository _repository;

  Future<WorkerProfile> call(List<String> locationIds) =>
      _repository.updatePreferredLocations(locationIds);
}
