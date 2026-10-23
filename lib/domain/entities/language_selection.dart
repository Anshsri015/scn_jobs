/// Proficiency levels for a worker's spoken/written language ability.
///
/// [apiValue] is what gets sent to / parsed from the backend's
/// `proficiency` field on `PATCH /worker/profile`'s `languages[]`
/// entries — kept separate from the enum name so the wire format is
/// explicit and doesn't silently break if the enum is ever renamed.
///
/// [label] display wording was updated from Beginner/Intermediate/
/// Advanced/Native to Basic/Good/Fluent/Excellent (UI-only change —
/// [apiValue] is untouched, so this doesn't affect what's sent to or
/// parsed from the backend). There is no backend value for a "No
/// English" / zero-proficiency option, so that's not included here —
/// add a 5th entry only once a matching apiValue is confirmed on the
/// backend side.
enum LanguageProficiency {
  beginner('BEGINNER', 'Basic'),
  intermediate('INTERMEDIATE', 'Good'),
  advanced('ADVANCED', 'Fluent'),
  native('NATIVE', 'Excellent');

  const LanguageProficiency(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static LanguageProficiency? fromApiValue(String? value) {
    if (value == null) return null;
    for (final level in LanguageProficiency.values) {
      if (level.apiValue == value) return level;
    }
    return null;
  }
}

/// One language a worker speaks, paired with how well they speak it.
///
/// Replaces the old flat `languageId` string that `WorkerProfile.languages`
/// used to hold — see `update_languages_usecase.dart`'s history for why
/// proficiency was deferred and is now being added.
class LanguageSelection {
  const LanguageSelection({
    required this.languageId,
    this.proficiency,
  });

  final String languageId;
  final LanguageProficiency? proficiency;

  LanguageSelection copyWith({LanguageProficiency? proficiency}) {
    return LanguageSelection(
      languageId: languageId,
      proficiency: proficiency ?? this.proficiency,
    );
  }
}