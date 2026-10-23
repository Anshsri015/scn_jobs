import 'package:scn_jobs/domain/entities/language_selection.dart';
import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/domain/repositories/profile_repository.dart';

/// Each selected language now carries a [LanguageProficiency] alongside
/// its id — see `LanguageSelection`'s doc for why this was deferred
/// earlier and is now being wired through.
class UpdateLanguagesUseCase {
  const UpdateLanguagesUseCase(this._repository);
  final ProfileRepository _repository;

  Future<WorkerProfile> call(List<LanguageSelection> languages) =>
      _repository.updateLanguages(languages);
}
