// ============================================
// APPLY SCREEN — Fixed (no job.location)
// ============================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/domain/entities/job.dart';
import 'package:scn_jobs/presentation/features/applications/applications_controller.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';
import 'package:scn_jobs/presentation/providers/jobs/job_providers.dart';

class ApplyScreen extends ConsumerStatefulWidget {
  const ApplyScreen({required this.job, super.key});

  final Job job;

  @override
  ConsumerState<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends ConsumerState<ApplyScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;

    // ✅ Re-enabled — resume upload is now confirmed working
    // end-to-end (WebView origin/InvalidURL fix), so this gate no
    // longer blocks every applicant. Uses the same `needsOnboarding`
    // signal the backend itself uses to decide whether a worker is
    // routed to onboarding vs the dashboard.
    final needsOnboarding = await ref.read(onboardingStatusProvider.future);
    if (needsOnboarding) {
      if (mounted) _promptCompleteProfile();
      return;
    }

    setState(() => _submitting = true);

    try {
      final useCase = ref.read(applyToJobUseCaseProvider);

      await useCase(widget.job.id);

      if (!mounted) return;

      // ✅ Refresh wrapped in its own try/catch — the apply call
      // above has ALREADY succeeded at this point. If refetching the
      // applications list hiccups, that's a separate, non-fatal
      // failure: it should NOT surface as "Something went wrong" for
      // the apply itself (root-caused via debug prints, 2026-09-11:
      // a `LateInitializationError` inside `ApplicationsController`
      // was making this refresh throw even though the apply had
      // already succeeded server-side — fixed at the source in
      // `applications_controller.dart`. This try/catch stays as a
      // safety net for any *other* transient refresh failure).
      try {
        await ref.refresh(applicationsControllerProvider.future);
      } catch (_) {
        // Swallow it — Job Detail will just show stale "Apply" until
        // its own next natural refresh. Not ideal, but far better
        // than lying to the user that their application failed.
      }

      if (!mounted) return;

      HapticFeedback.lightImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Application submitted!'),
            ],
          ),
        ),
      );

      // ✅ Single pop — back to Job Detail only. The previous double
      // pop also popped Job Detail itself, dropping the user straight
      // to the Jobs list, which is why re-opening the same job still
      // looked stale (a *second*, separate screen instance, not the
      // one that had just been refreshed).
      context.pop();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('========== APPLY ERROR ==========');
        debugPrint(e.toString());
        debugPrintStack(stackTrace: st);
        debugPrint('=================================');
      }

      if (mounted) {
        // The backend rejects a second apply on the same job with a
        // 400 ("You have already applied to this job"). Rather than
        // dumping the raw DioException, show the plain-English reason
        // and refresh the applications list so the job/Apply buttons
        // flip to "Applied" once we pop back.
        final message = e.toString().contains('already applied')
            ? "You've already applied to this job."
            : 'Something went wrong. Please try again.';

        if (e.toString().contains('already applied')) {
          ref.invalidate(applicationsControllerProvider);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _promptCompleteProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Text('Complete your profile before applying to jobs.'),
        action: SnackBarAction(
          label: 'Complete',
          textColor: Colors.orange.shade800,
          onPressed: () => context.push('/profile-setup/create'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final job = widget.job;
    final onboardingAsync = ref.watch(onboardingStatusProvider);

    // ✅ Re-enabled — see the matching note in `_submit()` above for
    // why this was temporarily hardcoded to false. While the check is
    // still loading, default to not-blocking (same as before) so the
    // button isn't stuck disabled on a slow connection — `_submit()`
    // does its own fresh check regardless, so this is just the UI
    // hint, not the actual gate.
    final profileIncomplete = onboardingAsync.when(
      data: (value) => value,
      loading: () => false,
      error: (_, __) => false,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, size: 20),
          ),
        ),
        title: const Text(
          'Apply',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Job Info Card ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primary.withOpacity(0.08),
                          colors.primary.withOpacity(0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                job.companyName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Profile Incomplete Warning ──
                  if (profileIncomplete)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 22,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Complete your profile to apply',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Recruiters need your education, experience and resume to consider you.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade700,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () =>
                                      context.push('/profile-setup/create'),
                                  child: Text(
                                    'Complete profile →',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Info Note ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your profile (name, education, experience, resume) will be shared with the recruiter automatically.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade800,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sticky Bottom CTA ──
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
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : profileIncomplete
                      ? () => _promptCompleteProfile()
                      : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: profileIncomplete
                        ? Colors.grey.shade300
                        : colors.primary,
                    foregroundColor:
                    profileIncomplete ? Colors.grey.shade600 : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        profileIncomplete
                            ? 'Complete Profile to Apply'
                            : 'Submit Application',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        profileIncomplete
                            ? Icons.lock_outline
                            : Icons.send_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
