import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';

/// Tracks the linear profile-setup flow: Create → Personal Details →
/// Education → Experience → Preferences → Resume. Each step's screen
/// reads [currentStep]/[stepRoutes] to know where it sits in the flow
/// and calls [completeCurrentStep] to advance — screens themselves
/// don't hardcode "what's next", only this controller does, so
/// reordering steps later is a one-file change.
///
/// Only the Create step (index 0) has a real screen as of Day 9 —
/// [stepRoutes] lists the rest ahead of time so this controller's shape
/// doesn't change again as Day 10/12/13 add their screens.
class ProfileSetupController extends AsyncNotifier<WorkerProfile?> {
  int _currentStep = 0;

  static const List<String> stepRoutes = [
    '/profile-setup/create',
    '/profile-setup/personal-details',
    '/profile-setup/education',
    '/profile-setup/experience',
    '/profile-setup/preferences',
    '/profile-setup/resume',
  ];

  int get currentStep => _currentStep;

  @override
  Future<WorkerProfile?> build() async {
    return null; // No profile until createProfile() succeeds.
  }

  Future<void> createProfile() async {
    state = const AsyncValue.loading();
    // ⚠️ POST /worker/profile is effectively obsolete per the
    // post-revamp API doc: /auth/worker/register already
    // auto-creates an empty WorkerProfile the moment the account
    // exists, so this call was failing for every real worker — either
    // with the documented "Profile already exists" conflict, or (as
    // seen in testing) a raw backend crash reading `workingStatus` off
    // an undefined record on some deployments. The doc's own guidance:
    // "Use PATCH /worker/profile as your default 'save onboarding
    // step' call, not this one." So instead of POSTing, just fetch the
    // profile that already exists.
    final useCase = ref.read(refreshProfileUseCaseProvider);
    state = await AsyncValue.guard(useCase.call);
    if (state.hasValue) _currentStep = 1;
  }

  /// Advances the step counter without changing [state]'s data — the
  /// profile itself is only ever mutated by calling a use case (e.g.
  /// personal-details, education screens on Day 10), never by this method.
  void completeCurrentStep() {
    if (_currentStep < stepRoutes.length - 1) _currentStep++;
  }
}

final profileSetupControllerProvider =
    AsyncNotifierProvider<ProfileSetupController, WorkerProfile?>(
  ProfileSetupController.new,
);

// WHY THIS FILE
// A single controller owning step order means `CreateProfileScreen`
// doesn't need to know "personal-details comes next" — it just calls
// `createProfile()` and reads whatever `stepRoutes[currentStep]` says.
// Alternative considered: each screen hardcoding `context.go('/next-hardcoded-path')`.
// Rejected — that scatters the step ordering across N screen files;
// reordering the flow (e.g. moving Resume earlier) would mean editing
// every screen's hardcoded next-route instead of one list here.
// Pitfall a junior would hit: calling `completeCurrentStep()` from
// inside a use-case success callback without also checking
// `state.hasError` first — advancing the step on a failed save would
// let the user "skip" a step whose data was never actually persisted.
