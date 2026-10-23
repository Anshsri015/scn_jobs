/// A single work-experience record on a worker's profile.
///
/// Field set is a best-guess scaffold, same caveat as `Education` — not
/// yet verified against the Profile API doc section.
class Experience {
  const Experience({
    required this.id,
    required this.companyName,
    required this.jobTitle,
    required this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.description,
  });

  final String id;
  final String companyName;
  final String jobTitle;
  final DateTime startDate;

  /// Null when [isCurrent] is true.
  final DateTime? endDate;
  final bool isCurrent;
  final String? description;

  Experience copyWith({
    String? companyName,
    String? jobTitle,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
    String? description,
  }) {
    return Experience(
      id: id,
      companyName: companyName ?? this.companyName,
      jobTitle: jobTitle ?? this.jobTitle,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCurrent: isCurrent ?? this.isCurrent,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Experience &&
          id == other.id &&
          companyName == other.companyName &&
          jobTitle == other.jobTitle &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          isCurrent == other.isCurrent &&
          description == other.description;

  @override
  int get hashCode => Object.hash(
        id,
        companyName,
        jobTitle,
        startDate,
        endDate,
        isCurrent,
        description,
      );
}
