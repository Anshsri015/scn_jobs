import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

class UpdateAssetsUseCase {
  const UpdateAssetsUseCase(this._repository);
  final ProfileRepository _repository;

  /// [assetNames] — plain names, not ids (see `WorkerProfile.assets`).
  Future<WorkerProfile> call(List<String> assetNames) =>
      _repository.updateAssets(assetNames);
}