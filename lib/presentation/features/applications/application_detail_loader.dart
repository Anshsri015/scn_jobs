import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scn_jobs/domain/entities/application.dart';
import 'package:scn_jobs/presentation/features/applications/application_detail_screen.dart';
import 'package:scn_jobs/presentation/providers/jobs/job_providers.dart';
import 'package:scn_jobs/presentation/shared_widgets/empty_state.dart'
    show EmptyState;

/// Used only when `/applications/:id` is reached WITHOUT an `extra:
/// Application` — i.e. a notification deep link (Day 18), not normal
/// in-app navigation from `MyApplicationsScreen` (which always supplies
/// `extra` and never hits this loader). See `app_router.go`'s builder
/// for the branch that picks this vs `ApplicationDetailScreen` directly.
final _applicationDetailProvider =
FutureProvider.autoDispose.family<Application, String>((ref, id) {
  final useCase = ref.watch(fetchApplicationDetailUseCaseProvider);
  return useCase(id);
});

class ApplicationDetailLoader extends ConsumerWidget {
  const ApplicationDetailLoader({required this.applicationId, super.key});

  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final applicationAsync =
    ref.watch(_applicationDetailProvider(applicationId));

    return applicationAsync.when(
      loading: () => const _DetailSkeleton(),
      error: (_, __) => _LoaderError(
        onRetry: () =>
            ref.invalidate(_applicationDetailProvider(applicationId)),
        primaryColor: colors.primary,
      ),
      data: (application) => ApplicationDetailScreen(application: application),
    );
  }
}

// ── Gradient header used by both loader states (matches detail screen) ──

class _LoaderHeader extends StatelessWidget {
  const _LoaderHeader({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(22),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Application Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Opacity(
                    opacity: 0,
                    child: IconButton(
                      onPressed: null,
                      icon: const SizedBox(width: 34, height: 34),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Loading skeleton: shimmer mimicking the detail layout ──

class _DetailSkeleton extends StatefulWidget {
  const _DetailSkeleton();

  @override
  State<_DetailSkeleton> createState() => _DetailSkeletonState();
}

class _DetailSkeletonState extends State<_DetailSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final dx = rect.width * (_controller.value * 2 - 1);
            return LinearGradient(
              begin: Alignment(dx - 0.5, 0),
              end: Alignment(dx + 0.5, 0),
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            // Header mock (hero area with avatar + title + pill)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 140,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 44),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: 180,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 110,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: 110,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Card skeletons
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state: gradient header + EmptyState, matching the app look ──

class _LoaderError extends StatelessWidget {
  const _LoaderError({required this.onRetry, required this.primaryColor});

  final VoidCallback onRetry;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          _LoaderHeader(
            child: Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 36,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Couldn't load this application",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
