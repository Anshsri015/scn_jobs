import 'package:scn_jobs/domain/entities/experience.dart';

/// Maps `Experience` to/from the `/worker/experience` JSON shape.
///
/// The API's field names (`fromDate`, `toDate`) differ from the
/// entity's (`startDate`, `endDate`) — the entity keeps its own naming
/// since it read more naturally next to `isCurrent`/`description`
/// everywhere else in the app; this model is the only place the rename
/// happens.
class ExperienceModel extends Experience {
  const ExperienceModel({
    required super.id,
    required super.companyName,
    required super.jobTitle,
    required super.startDate,
    super.endDate,
    super.isCurrent,
    super.description,
  });

  factory ExperienceModel.fromJson(Map<String, dynamic> json) {
    return ExperienceModel(
      id: json['id']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      jobTitle: json['jobTitle']?.toString() ?? '',
      startDate: DateTime.tryParse(json['fromDate']?.toString() ?? '') ??
          DateTime.now(),
      endDate: json['toDate'] != null
          ? DateTime.tryParse(json['toDate'].toString())
          : null,
      isCurrent: json['isCurrent'] as bool? ?? false,
      description: json['description']?.toString(),
    );
  }

  /// Body for `POST`/`PATCH /worker/experience`.
  Map<String, dynamic> toRequestBody() {
    return {
      'companyName': companyName,
      'jobTitle': jobTitle,
      'fromDate': startDate.toIso8601String(),
      if (endDate != null) 'toDate': endDate!.toIso8601String(),
      'isCurrent': isCurrent,
      if (description != null) 'description': description,
    };
  }
}
