import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

/// Separate from `UploadResumeUseCase` on purpose — uploading a file and
/// persisting its resulting URL onto the profile are two different
/// failure domains (network/multipart vs profile-update), and
/// `ResumeUploadScreen` calls them as two explicit steps so a failure
/// in step 2 doesn't get misreported as an upload failure in step 1.
class UpdateResumeUrlUseCase {
  const UpdateResumeUrlUseCase(this._repository);
  final ProfileRepository _repository;

  Future<WorkerProfile> call(String resumeUrl) =>
      _repository.updateResumeUrl(resumeUrl);
}
