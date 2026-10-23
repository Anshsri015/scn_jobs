import 'package:scn_jobs/core/storage/isar_service.dart';
import 'package:scn_jobs/domain/repositories/auth_repository.dart';

/// Mirrors `LogoutUseCase`'s reasoning exactly — deleting the account
/// must also wipe the local Isar cache, not just the auth token, for
/// the same shared-device reason. See `LogoutUseCase`'s WHY block.
class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._repository, this._isarService);

  final AuthRepository _repository;
  final IsarService _isarService;

  Future<void> call() async {
    await _repository.deleteAccount();
    await _isarService.clearAllData();
  }
}
