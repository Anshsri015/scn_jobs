import 'package:scn_jobs/domain/entities/application_status.dart';
import 'package:scn_jobs/domain/entities/job.dart' show Job;

/// [jobTitle]/[companyName] are denormalized copies from the [Job] at
/// the time of applying — kept here so `MyApplicationsScreen` (Day 17)
/// can render a list without a second round-trip per row to fetch each
/// job's current title (which could also legitimately change or be
/// deleted after applying).
class Application {
  const Application({
    required this.id,
    required this.jobId,
    required this.status,
    required this.appliedAt,
    this.jobTitle,
    this.companyName,
  });

  final String id;
  final String jobId;
  final ApplicationStatus status;
  final DateTime appliedAt;
  final String? jobTitle;
  final String? companyName;

  /// Withdraw is a `DELETE /applications/:id` server-side, which only
  /// makes sense before a final decision has been made. Once a
  /// recruiter/admin has `accepted` or `rejected` the application,
  /// it's terminal — no further status change (including withdraw)
  /// is meaningful. Only `applied` stays withdrawable.
  bool get canWithdraw => status == ApplicationStatus.applied;
}
