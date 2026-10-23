/// A single education record on a worker's profile.
///
/// Field set is confirmed against the code-verified API doc (Section
/// 6.1, `POST/PATCH /worker/education`). The real contract is:
/// `level` (required enum — TEN | TWELVE | DIPLOMA | GRADUATE |
/// POST_GRADUATE | ANY), then EITHER `qualificationId` (a reference
/// into master-data `QualificationItem`, required for every level
/// except ANY) OR `qualificationName` (free text, ONLY accepted when
/// `level == ANY`), plus an optional `institute`.
///
/// `passoutYear` and `score` are NOT part of this endpoint — the doc's
/// example payloads and response shape (`id`, `level`, `institute`
/// only) confirm the backend doesn't store them, so they've been
/// dropped rather than silently never reaching the server.
class Education {
  const Education({
    required this.id,
    required this.level,
    this.qualificationId,
    this.qualificationName,
    this.institute,
  });

  final String id;

  /// One of TEN | TWELVE | DIPLOMA | GRADUATE | POST_GRADUATE | ANY —
  /// matches `QualificationItem.level` / `GET /master/qualifications`'s
  /// grouping key. Required on every entry.
  final String level;

  /// References `QualificationItem.id` from master data, scoped to
  /// [level]. Required unless [level] is ANY (in which case
  /// [qualificationName] is used instead).
  final String? qualificationId;

  /// Free-text qualification label — ONLY valid/sent when [level] is
  /// ANY (e.g. an ad-hoc certification not in the master list). For
  /// every other level this is display-only (populated locally from
  /// the matched `QualificationItem.name`, never sent to the backend).
  final String? qualificationName;
  final String? institute;

  Education copyWith({
    String? level,
    String? qualificationId,
    String? qualificationName,
    String? institute,
  }) {
    return Education(
      id: id,
      level: level ?? this.level,
      qualificationId: qualificationId ?? this.qualificationId,
      qualificationName: qualificationName ?? this.qualificationName,
      institute: institute ?? this.institute,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Education &&
              id == other.id &&
              level == other.level &&
              qualificationId == other.qualificationId &&
              qualificationName == other.qualificationName &&
              institute == other.institute;

  @override
  int get hashCode =>
      Object.hash(id, level, qualificationId, qualificationName, institute);
}

// WHY THIS FILE CHANGED (against the code-verified API doc)
// Previous shape assumed `qualificationId` was always required and
// added `passoutYear`/`score` fields the endpoint never documented.
// The real doc adds a required `level` enum (this is what the
// screenshot's "Qualification Level" dropdown actually selects) and
// makes `qualificationId` conditional: required for TEN/TWELVE/
// DIPLOMA/GRADUATE/POST_GRADUATE, replaced by free-text
// `qualificationName` only when `level == ANY`.
// Pitfall a junior would hit: sending both `qualificationId` and
// `qualificationName` together, or sending `qualificationName` when
// `level != ANY` — the backend only accepts the one that matches the
// chosen level.