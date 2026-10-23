import 'package:scn_jobs/data/datasources/profile_remote_datasource.dart';
import 'package:scn_jobs/data/models/experience_model.dart';
import 'package:scn_jobs/domain/entities/experience.dart';
import 'package:scn_jobs/domain/repositories/experience_repository.dart';

/// Same caveat as `EducationRepositoryImpl`: no standalone
/// `GET /worker/experience`, so [list] fetches the whole profile.
class ExperienceRepositoryImpl implements ExperienceRepository {
  ExperienceRepositoryImpl(this._remoteDataSource);

  final ProfileRemoteDataSource _remoteDataSource;

  @override
  Future<List<Experience>> list() async {
    final profile = await _remoteDataSource.getProfile();
    return profile.experience;
  }

  @override
  Future<Experience> add(Experience experience) {
    return _remoteDataSource.addExperience(_toModel(experience));
  }

  @override
  Future<Experience> update(Experience experience) {
    return _remoteDataSource.updateExperience(_toModel(experience));
  }

  @override
  Future<void> remove(String experienceId) {
    return _remoteDataSource.removeExperience(experienceId);
  }

  ExperienceModel _toModel(Experience experience) {
    return ExperienceModel(
      id: experience.id,
      companyName: experience.companyName,
      jobTitle: experience.jobTitle,
      startDate: experience.startDate,
      endDate: experience.endDate,
      isCurrent: experience.isCurrent,
      description: experience.description,
    );
  }
}
