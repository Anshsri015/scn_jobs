import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/network/dio_provider.dart';
import 'package:scn_jobs/data/datasources/profile_remote_datasource.dart';
import 'package:scn_jobs/data/repositories/education_repository_impl.dart';
import 'package:scn_jobs/data/repositories/experience_repository_impl.dart';
import 'package:scn_jobs/data/repositories/profile_repository_impl.dart';
import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/education_repository.dart';
import 'package:scn_jobs/domain/repositories/experience_repository.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';
import 'package:scn_jobs/domain/usecases/add_education_usecase.dart';
import 'package:scn_jobs/domain/usecases/add_experience_usecase.dart';
import 'package:scn_jobs/domain/usecases/create_profile_usecase.dart';
import 'package:scn_jobs/domain/usecases/refresh_profile_usecase.dart';
import 'package:scn_jobs/domain/usecases/remove_education_usecase.dart';
import 'package:scn_jobs/domain/usecases/remove_experience_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_education_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_experience_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_languages_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_assets_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_preferred_departments_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_preferred_industries_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_preferred_job_roles_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_preferred_locations_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_profile_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_resume_url_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_skills_usecase.dart';
import 'package:scn_jobs/domain/usecases/update_working_status_usecase.dart';

/// Backs profile, education, and experience repositories — all three
/// go through the same `/worker/*` surface via one datasource, see
/// `ProfileRemoteDataSource`'s WHY note.
final profileRemoteDataSourceProvider =
Provider<ProfileRemoteDataSource>((ref) {
  return ProfileRemoteDataSource(ref.watch(dioProvider));
});

/// Day 8 landed — this now constructs the real, backend-backed impls
/// instead of the old in-memory stubs. Every use case and screen below
/// depends only on the abstract repository interfaces, so nothing else
/// changed when this swap happened.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider));
});

final educationRepositoryProvider = Provider<EducationRepository>((ref) {
  return EducationRepositoryImpl(ref.watch(profileRemoteDataSourceProvider));
});

final experienceRepositoryProvider = Provider<ExperienceRepository>((ref) {
  return ExperienceRepositoryImpl(ref.watch(profileRemoteDataSourceProvider));
});

final createProfileUseCaseProvider = Provider<CreateProfileUseCase>((ref) {
  return CreateProfileUseCase(ref.watch(profileRepositoryProvider));
});

final updateProfileUseCaseProvider = Provider<UpdateProfileUseCase>((ref) {
  return UpdateProfileUseCase(ref.watch(profileRepositoryProvider));
});

final addEducationUseCaseProvider = Provider<AddEducationUseCase>((ref) {
  return AddEducationUseCase(ref.watch(educationRepositoryProvider));
});

final updateEducationUseCaseProvider = Provider<UpdateEducationUseCase>((ref) {
  return UpdateEducationUseCase(ref.watch(educationRepositoryProvider));
});

final removeEducationUseCaseProvider = Provider<RemoveEducationUseCase>((ref) {
  return RemoveEducationUseCase(ref.watch(educationRepositoryProvider));
});

final addExperienceUseCaseProvider = Provider<AddExperienceUseCase>((ref) {
  return AddExperienceUseCase(ref.watch(experienceRepositoryProvider));
});

final updateExperienceUseCaseProvider =
Provider<UpdateExperienceUseCase>((ref) {
  return UpdateExperienceUseCase(ref.watch(experienceRepositoryProvider));
});

final removeExperienceUseCaseProvider =
Provider<RemoveExperienceUseCase>((ref) {
  return RemoveExperienceUseCase(ref.watch(experienceRepositoryProvider));
});

final updateSkillsUseCaseProvider = Provider<UpdateSkillsUseCase>((ref) {
  return UpdateSkillsUseCase(ref.watch(profileRepositoryProvider));
});

final updateWorkingStatusUseCaseProvider =
Provider<UpdateWorkingStatusUseCase>((ref) {
  return UpdateWorkingStatusUseCase(ref.watch(profileRepositoryProvider));
});

final updateLanguagesUseCaseProvider = Provider<UpdateLanguagesUseCase>((ref) {
  return UpdateLanguagesUseCase(ref.watch(profileRepositoryProvider));
});

final updatePreferredLocationsUseCaseProvider =
Provider<UpdatePreferredLocationsUseCase>((ref) {
  return UpdatePreferredLocationsUseCase(ref.watch(profileRepositoryProvider));
});

final updatePreferredIndustriesUseCaseProvider =
Provider<UpdatePreferredIndustriesUseCase>((ref) {
  return UpdatePreferredIndustriesUseCase(ref.watch(profileRepositoryProvider));
});

final updatePreferredJobRolesUseCaseProvider =
Provider<UpdatePreferredJobRolesUseCase>((ref) {
  return UpdatePreferredJobRolesUseCase(ref.watch(profileRepositoryProvider));
});

final updatePreferredDepartmentsUseCaseProvider =
Provider<UpdatePreferredDepartmentsUseCase>((ref) {
  return UpdatePreferredDepartmentsUseCase(ref.watch(profileRepositoryProvider));
});

final updateAssetsUseCaseProvider = Provider<UpdateAssetsUseCase>((ref) {
  return UpdateAssetsUseCase(ref.watch(profileRepositoryProvider));
});

final updateResumeUrlUseCaseProvider = Provider<UpdateResumeUrlUseCase>((ref) {
  return UpdateResumeUrlUseCase(ref.watch(profileRepositoryProvider));
});

final refreshProfileUseCaseProvider = Provider<RefreshProfileUseCase>((ref) {
  return RefreshProfileUseCase(ref.watch(profileRepositoryProvider));
});

/// Watched by `EditProfileScreen` to prefill the form, and by
/// `route_guards.dart`'s intended `profileCompleteGuard` (not yet
/// wired here — see the Day 14 router note) to decide whether a
/// logged-in user should be redirected into profile-setup.
final currentProfileProvider = FutureProvider<WorkerProfile>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});
