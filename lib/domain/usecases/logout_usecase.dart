import 'package:scn_jobs/core/storage/isar_service.dart';
import 'package:scn_jobs/domain/repositories/auth_repository.dart';

/// Orchestrates everything that must happen on logout: remote logout +
/// clearing the local token (via [AuthRepository.logout]) AND wiping
/// the local Isar cache. These are two different storage systems with
/// two different owners (auth vs. general app cache) — this use case
/// is the one place that knows both need clearing together, so no
/// caller can accidentally clear one but not the other.
class LogoutUseCase {
  const LogoutUseCase(this._repository, this._isarService);

  final AuthRepository _repository;
  final IsarService _isarService;

  Future<void> call() async {
    await _repository.logout();
    await _isarService.clearAllData();
  }
}

// WHY THIS FILE
// Logout has to clear more than the auth token — cached jobs,
// applications, and profile data from the *previous* user must not
// leak into whatever the *next* login on this device sees (shared
// devices are common for this app's audience). Putting that
// orchestration in a use case, not in `AuthRepository.logout()` itself,
// keeps `AuthRepository` scoped to auth concerns only — it has no
// business knowing Isar exists.
// Alternative considered: clearing Isar inside `AuthRepositoryImpl.logout()`
// directly. Rejected — that repository already has one storage
// dependency (`SecureStorageService`); adding `IsarService` too makes it
// responsible for two unrelated systems, and every future repository
// that also wants "clear my cache on logout" would need its own copy of
// this same call instead of composing through one use case.
// Pitfall a junior would hit: calling `AuthRepository.logout()` directly
// from a screen instead of going through `LogoutUseCase` — that
// technically logs the user out but silently leaves the Isar cache
// intact, a bug that's invisible until the *next* user on a shared
// device sees the previous worker's cached job list for a moment.
