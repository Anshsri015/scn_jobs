import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/network/pagination.dart';
import 'package:scn_jobs/domain/entities/application.dart';
import 'package:scn_jobs/domain/usecases/fetch_my_applications_usecase.dart';
import 'package:scn_jobs/domain/usecases/withdraw_application_usecase.dart';
import 'package:scn_jobs/presentation/providers/jobs/job_providers.dart';

class ApplicationsController extends AsyncNotifier<Page<Application>> {
  // ✅ Getters instead of `late final` fields set inside `build()`.
  // Root-caused via debug print (2026-09-11): calling
  // `ref.refresh(applicationsControllerProvider.future)` right after
  // a successful apply threw `LateInitializationError: Field
  // '_fetchUseCase' has already been initialized` — meaning `build()`
  // ran a second time on the SAME notifier instance rather than a
  // fresh one, which `late final` can't survive. Usecases are cheap
  // thin wrappers around the repository, so recomputing them on every
  // access is fine and makes this immune to how many times `build()`
  // (or these methods) get invoked on one instance.
  FetchMyApplicationsUseCase get _fetchUseCase =>
      FetchMyApplicationsUseCase(ref.read(applicationRepositoryProvider));
  WithdrawApplicationUseCase get _withdrawUseCase =>
      WithdrawApplicationUseCase(ref.read(applicationRepositoryProvider));

  @override
  Future<Page<Application>> build() async {
    return _fetchUseCase();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchUseCase());
  }

  /// Optimistic-refresh, not optimistic-update: rather than mutating
  /// the in-memory list to mark one item withdrawn (which would drift
  /// from the server's actual status if the withdraw silently failed
  /// server-side for a reason the client can't see), this just
  /// re-fetches the whole list after a successful withdraw. Simpler,
  /// and correct-by-construction at the cost of one extra network call.
  Future<void> withdraw(String applicationId) async {
    await _withdrawUseCase(applicationId);
    await refresh();
  }
}

final applicationsControllerProvider =
AsyncNotifierProvider<ApplicationsController, Page<Application>>(
  ApplicationsController.new,
);
