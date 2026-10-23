import 'package:scn_jobs/core/network/pagination.dart';
import 'package:scn_jobs/domain/entities/job.dart';

abstract class JobRepository {
  /// [cursor] is whatever `Page<Job>.cursor` returned last time — see
  /// `pagination.dart`'s WHY block for why the pagination style itself
  /// (cursor vs offset) is still unconfirmed.
  Future<Page<Job>> getJobs({
    String? cursor,
    String? searchQuery,
    List<String>? locationIds,
    List<String>? industryIds,
  });

  Future<Job> getJobDetail(String jobId);
}
