import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';

/// Reached right after the resume-upload step. Calls
/// `RefreshProfileUseCase` so the backend's `isComplete` flag (whatever
/// rule it applies) is fetched fresh, then shows a short confirmation
/// before landing on Home.
class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _hasError = false;

  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _checkScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOut),
    );
    _refresh();
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      // TEMP DEBUG — see AuthRemoteDataSource.getOnboardingStatus's
      // note: comparing this timestamp against the onboarding-status
      // debug line tells us if this is firing before the backend's
      // resume-upload webhook has actually landed.
      if (kDebugMode) {
        debugPrint(
          "=========== profile_completion_screen _refresh() — ${DateTime.now().toIso8601String()} ===========",
        );
      }
      await ref.read(refreshProfileUseCaseProvider)();
      ref.invalidate(currentProfileProvider);

      // ⚠️ A single `ref.invalidate(onboardingStatusProvider)` here
      // was the bug behind "1st time profile complete save nahi hota,
      // 2nd baar ho jaata hai": `GET /auth/onboarding-status`'s
      // `needsOnboarding` flag is computed independently of (and can
      // lag behind) the `resumeUrl` webhook — ResumeUploadScreen
      // already polls `GET /worker/profile` until `resumeUrl` lands
      // (see `ProfileRepositoryImpl.updateResumeUrl`), but that says
      // nothing about whether the backend has *also* finished
      // recomputing `needsOnboarding` by the time we land here. One
      // immediate check could still catch it stale (true), and that
      // stale `false→true` result got cached by Riverpod — Settings
      // and the Apply gate then kept nagging "complete your profile"
      // until the worker redid the whole wizard a second time, by
      // which point the backend had finally caught up.
      //
      // Fix: poll the SAME way `updateResumeUrl` already does, until
      // the backend actually reports onboarding as done (or we give
      // up after a few tries — the worker can still hit "Try Again").
      const maxOnboardingChecks = 5;
      const delayBetweenChecks = Duration(seconds: 2);
      for (var attempt = 1; attempt <= maxOnboardingChecks; attempt++) {
        final needsOnboarding =
        await ref.refresh(onboardingStatusProvider.future);
        if (!needsOnboarding) break;
        if (attempt < maxOnboardingChecks) {
          await Future.delayed(delayBetweenChecks);
        }
      }

      if (mounted) {
        setState(() => _loading = false);
        HapticFeedback.mediumImpact();
        _checkController.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const _LoadingState()
            : _hasError
            ? _ErrorState(onRetry: _refresh)
            : _SuccessState(
          checkScale: _checkScale,
          fadeIn: _fadeIn,
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Loading state
/// ─────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 48,
            width: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Finishing up your profile…',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Just a moment while we save everything and prepare your dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Error state
/// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          /// Error illustration
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.shade400,
            ),
          ),

          const SizedBox(height: 32),

          Text(
            "Couldn't confirm your profile",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Your details are saved — this is just a final check. Try again or skip to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),

          const Spacer(),

          /// Retry button
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          /// Skip button
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => context.go('/home'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Skip for now',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Success state — CELEBRATION!
/// ─────────────────────────────────────────────
class _SuccessState extends StatelessWidget {
  const _SuccessState({
    required this.checkScale,
    required this.fadeIn,
  });

  final Animation<double> checkScale;
  final Animation<double> fadeIn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 60),

          /// Animated checkmark
          ScaleTransition(
            scale: checkScale,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade400,
                    Colors.green.shade600,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.shade400.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 72,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 36),

          /// Headline with fade
          FadeTransition(
            opacity: fadeIn,
            child: Column(
              children: [
                Text(
                  'Your profile is ready!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Recruiters can now find you. Start browsing jobs that match your skills and location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          /// Profile stats cards
          FadeTransition(
            opacity: fadeIn,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.verified_rounded,
                        iconColor: Colors.green.shade500,
                        iconBg: Colors.green.shade50,
                        value: '100%',
                        label: 'Profile complete',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.visibility_rounded,
                        iconColor: colors.primary,
                        iconBg: colors.primary.withOpacity(0.08),
                        value: 'Visible',
                        label: 'To recruiters',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.work_outline_rounded,
                        iconColor: Colors.amber.shade600,
                        iconBg: Colors.amber.shade50,
                        value: 'Ready',
                        label: 'To apply',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.notifications_active_rounded,
                        iconColor: Colors.blue.shade500,
                        iconBg: Colors.blue.shade50,
                        value: 'Active',
                        label: 'Job alerts',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          /// Primary CTA
          FadeTransition(
            opacity: fadeIn,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Start Browsing Jobs',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 22),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          /// Secondary CTA
          FadeTransition(
            opacity: fadeIn,
            child: TextButton(
              onPressed: () => context.go('/home'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade500,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text(
                'Go to Dashboard',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Stat card widget
/// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
