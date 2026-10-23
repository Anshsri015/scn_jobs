import 'package:scn_jobs/domain/entities/education.dart';

abstract class EducationRepository {
  Future<List<Education>> list();

  /// [education.id] is ignored on add — the backend assigns the real id;
  /// the returned [Education] carries it.
  Future<Education> add(Education education);

  Future<Education> update(Education education);

  Future<void> remove(String educationId);
}
