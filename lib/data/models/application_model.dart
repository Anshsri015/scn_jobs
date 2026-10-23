import 'package:scn_jobs/domain/entities/application.dart';
import 'package:scn_jobs/domain/entities/application_status.dart';

/// ⚠️ Response shape for `POST /applications` and `GET /applications/my`
/// isn't spelled out field-by-field in the API doc the way `/jobs` is —
/// same caveat every other "confirmed endpoint, best-guess shape" model
/// in this codebase carries (see `JobModel`, `WorkerProfileModel`).
/// Best guess here, modeled on `JobModel.fromJson`'s pattern: try a
/// flattened `jobTitle`/`companyName` first (in case the backend
/// denormalizes them directly onto the application), then fall back to
/// a nested `job` object (`{ job: { title, poster: { recruiter: { name
/// } } } }`, mirroring how `/jobs` itself nests `poster.recruiter`).
/// Only this file's parsing needs to change if the real shape differs
/// — nothing above the data layer depends on which branch fires.
class ApplicationModel extends Application {
  const ApplicationModel({
    required super.id,
    required super.jobId,
    required super.status,
    required super.appliedAt,
    super.jobTitle,
    super.companyName,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    final nestedJob = json['job'] as Map<String, dynamic>?;
    final recruiter = (nestedJob?['poster'] as Map<String, dynamic>?)?['recruiter']
        as Map<String, dynamic>?;

    final jobTitle = json['jobTitle']?.toString() ??
        (nestedJob?['jobRole'] as Map<String, dynamic>?)?['name']?.toString();
    final companyName = json['companyName']?.toString() ??
        recruiter?['name']?.toString();

    final jobIdRaw = json['jobId'] ?? nestedJob?['id'] ?? nestedJob?['_id'];

    final statusRaw = json['status']?.toString();

    return ApplicationModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      jobId: jobIdRaw?.toString() ?? '',
      status: statusRaw != null
          ? applicationStatusFromString(statusRaw)
          : ApplicationStatus.applied,
      appliedAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      jobTitle: jobTitle,
      companyName: companyName,
    );
  }
}
