import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/storage/isar_service.dart';
import 'package:scn_jobs/domain/usecases/delete_account_usecase.dart';
import 'package:scn_jobs/domain/usecases/logout_usecase.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';

class AccountController extends AsyncNotifier<void> {
  late final LogoutUseCase _logoutUseCase;
  late final DeleteAccountUseCase _deleteAccountUseCase;

  @override
  Future<void> build() async {
    final repo = ref.read(authRepositoryProvider);
    _logoutUseCase = LogoutUseCase(repo, IsarService.instance);
    _deleteAccountUseCase = DeleteAccountUseCase(repo, IsarService.instance);
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _logoutUseCase());
    if (!state.hasError) {
      ref.invalidate(authStateProvider);
      // ⚠️ FIX: currentProfileProvider is a plain (non-autoDispose)
      // FutureProvider — it caches the last-fetched WorkerProfile
      // (including photo/personal details) in memory forever unless
      // explicitly invalidated. Without this, the *next* login on
      // this device (same or different account) sees the previous
      // worker's cached profile until something else happens to
      // invalidate it (e.g. visiting Edit Profile).
      ref.invalidate(currentProfileProvider);
    }
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _deleteAccountUseCase());
    if (!state.hasError) {
      ref.invalidate(authStateProvider);
      ref.invalidate(currentProfileProvider);
    }
  }
}

final accountControllerProvider =
AsyncNotifierProvider<AccountController, void>(AccountController.new);