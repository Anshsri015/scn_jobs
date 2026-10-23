import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/network/dio_provider.dart';
import 'package:scn_jobs/presentation/features/profile_setup/profile_setup_controller.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';

class CreateProfileScreen extends ConsumerWidget {
  const CreateProfileScreen({super.key});

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    await ref.read(profileSetupControllerProvider.notifier).createProfile();
    final state = ref.read(profileSetupControllerProvider);

    if (!context.mounted) return;

    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 10),
              const Text("Couldn't create your profile. Try again."),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // WHY `push` not `go`: `go()` replaces the whole navigation
    // stack, so every step-to-step hop in this wizard used to wipe
    // out the screen the worker started from (e.g. the Apply screen,
    // or Home) — leaving nothing for system back to pop to, which is
    // why pressing back mid-wizard closed the app instead of going to
    // the previous step. `push()` keeps a real back stack; the wizard
    // only truly "exits" (and correctly uses `.go('/home')`) at Skip
    // or on final completion in `ProfileCompletionScreen`.
    context.push('/profile-setup/personal-details');
  }

  /// Persists the skip so `route_guards.dart` doesn't bounce the
  /// worker straight back here on the next navigation/app restart —
  /// without this, "Skip for now" only worked for the current screen,
  /// not going forward.
  Future<void> _skipToHome(BuildContext context, WidgetRef ref) async {
    await ref.read(secureStorageServiceProvider).markOnboardingSkipped();
    ref.invalidate(onboardingSkippedProvider);
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileSetupControllerProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// Top bar with SKIP
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isLoading ? null : () => _skipToHome(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade500,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    /// Progress indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Step 1 of 4',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    /// Hero illustration
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  colors.primary.withOpacity(0.15),
                                  colors.primary.withOpacity(0.02),
                                ],
                                radius: 0.8,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colors.primary,
                                  colors.primary.withBlue(
                                    (colors.primary.blue * 0.8).round(),
                                  ),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withOpacity(0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 52,
                              color: Colors.white,
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 20,
                            child: _FloatingBadge(
                              icon: Icons.verified_rounded,
                              color: Colors.green.shade500,
                              delay: const Duration(milliseconds: 200),
                            ),
                          ),
                          Positioned(
                            left: 15,
                            bottom: 25,
                            child: _FloatingBadge(
                              icon: Icons.work_outline_rounded,
                              color: Colors.amber.shade500,
                              delay: const Duration(milliseconds: 400),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    Text(
                      "Let's build your\nprofile",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                        height: 1.15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'A complete profile helps recruiters find you faster and increases your chances of getting hired by 3x.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 36),

                    _BenefitCard(
                      icon: Icons.flash_on_rounded,
                      iconColor: Colors.orange.shade500,
                      iconBg: Colors.orange.shade50,
                      title: 'Get noticed faster',
                      subtitle: 'Recruiters see complete profiles first',
                    ),
                    const SizedBox(height: 12),
                    _BenefitCard(
                      icon: Icons.call_received_rounded,
                      iconColor: Colors.green.shade500,
                      iconBg: Colors.green.shade50,
                      title: 'Direct job calls',
                      subtitle: 'Employers contact you directly',
                    ),
                    const SizedBox(height: 12),
                    _BenefitCard(
                      icon: Icons.timer_outlined,
                      iconColor: colors.primary,
                      iconBg: colors.primary.withOpacity(0.08),
                      title: 'Takes only 2 minutes',
                      subtitle: 'Quick and easy step-by-step setup',
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            /// Bottom CTA section
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () => _continue(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isLoading
                            ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'You can edit your profile anytime',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingBadge extends StatefulWidget {
  const _FloatingBadge({
    required this.icon,
    required this.color,
    required this.delay,
  });

  final IconData icon;
  final Color color;
  final Duration delay;

  @override
  State<_FloatingBadge> createState() => _FloatingBadgeState();
}

class _FloatingBadgeState extends State<_FloatingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(widget.icon, size: 20, color: widget.color),
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
