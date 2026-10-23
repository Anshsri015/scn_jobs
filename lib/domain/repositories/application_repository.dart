import 'package:scn_jobs/core/network/pagination.dart';
import 'package:scn_jobs/domain/entities/application.dart';

abstract class ApplicationRepository {
  /// [coverNote] is optional — the Apply screen's cover-note field is
  /// not required to submit an application.
  Future<Application> applyToJob(String jobId, {String? coverNote});

  Future<Page<Application>> getMyApplications({String? cursor});

  /// Fetch a single application by id — added for Day 18's notification
  /// deep-link case, where `/applications/:id` is opened without the
  /// `extra: Application` that in-app navigation normally supplies (see
  /// `app_router.dart`'s WHY block, which flagged this exact gap).
  Future<Application> getApplicationDetail(String applicationId);

  Future<void> withdrawApplication(String applicationId);
}
