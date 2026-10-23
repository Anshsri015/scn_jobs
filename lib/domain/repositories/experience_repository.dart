import 'package:scn_jobs/domain/entities/experience.dart';

abstract class ExperienceRepository {
  Future<List<Experience>> list();

  /// [experience.id] is ignored on add — the backend assigns the real
  /// id; the returned [Experience] carries it.
  Future<Experience> add(Experience experience);

  Future<Experience> update(Experience experience);

  Future<void> remove(String experienceId);
}
