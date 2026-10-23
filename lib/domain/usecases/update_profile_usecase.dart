import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository);
  final ProfileRepository _repository;

  /// Only non-null parameters are treated as "changed" — this mirrors
  /// `ProfileRepository.updatePersonalDetails`'s partial-update contract.
  Future<WorkerProfile> call({
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? state,
    String? city,
    String? locality,
    String? photoUrl,
    String? headline,
    String? summary,
    int? totalExperienceMonths,
    int? expectedSalaryMin,
    int? expectedSalaryMax,
    String? alternatePhone,
    String? maritalStatus,
    String? category,
  }) {
    return _repository.updatePersonalDetails(
      name: name,
      dateOfBirth: dateOfBirth,
      gender: gender,
      state: state,
      city: city,
      locality: locality,
      photoUrl: photoUrl,
      headline: headline,
      summary: summary,
      totalExperienceMonths: totalExperienceMonths,
      expectedSalaryMin: expectedSalaryMin,
      expectedSalaryMax: expectedSalaryMax,
      alternatePhone: alternatePhone,
      maritalStatus: maritalStatus,
      category: category,
    );
  }
}
