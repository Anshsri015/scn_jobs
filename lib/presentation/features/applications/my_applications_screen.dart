import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:scn_jobs/domain/entities/application.dart';
import 'package:scn_jobs/domain/entities/application_status.dart';
import 'package:scn_jobs/presentation/features/applications/applications_controller.dart';
import 'package:scn_jobs/presentation/shared_widgets/empty_state.dart';

class MyApplicationsScreen extends ConsumerStatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  ConsumerState<MyApplicationsScreen> createState() =>
      _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends ConsumerState<MyApplicationsScreen> {
  @override
  void initState() {
    super.initState();
    // Screen open hote hi refresh — latest data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(applicationsControllerProvider.notifier).refresh();
    });
  }

  Color _statusColor(ApplicationStatus status, ColorScheme scheme) =>
      switch (status) {
        ApplicationStatus.applied => scheme.primary,
        ApplicationStatus.accepted => Colors.green.shade600,
        ApplicationStatus.rejected => scheme.error,
      };

  Gradient _avatarGradient(ApplicationStatus status, ColorScheme scheme) {
    return switch (status) {
      ApplicationStatus.applied => LinearGradient(
        colors: [scheme.primary, scheme.primary.withOpacity(0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      ApplicationStatus.accepted => LinearGradient(
        colors: [Colors.green.shade500, Colors.teal.shade500],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      ApplicationStatus.rejected => LinearGradient(
        colors: [scheme.error, scheme.error.withOpacity(0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    };
  }

  Color _statusBgColor(ApplicationStatus status, ColorScheme scheme) =>
      switch (status) {
        ApplicationStatus.applied => scheme.primary.withOpacity(0.08),
        ApplicationStatus.accepted => Colors.green.shade50,
        ApplicationStatus.rejected => Colors.red.shade50,
      };

  IconData _statusIcon(ApplicationStatus status) => switch (status) {
    ApplicationStatus.applied => Icons.send_rounded,
    ApplicationStatus.accepted => Icons.celebration_rounded,
    ApplicationStatus.rejected => Icons.cancel_rounded,
  };

  String _statusLabel(ApplicationStatus status) => switch (status) {
    ApplicationStatus.applied => 'Applied',
    ApplicationStatus.accepted => 'Accepted',
    ApplicationStatus.rejected => 'Not selected',
  };

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final applicationsAsync = ref.watch(applicationsControllerProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: applicationsAsync.when(
        loading: () => const _LoadingState(),
        error: (_, __) => EmptyState(
          icon: Icons.error_outline_rounded,
          message: "Couldn't load your applications.",
          actionLabel: 'Retry',
          onAction: () =>
              ref.read(applicationsControllerProvider.notifier).refresh(),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return _EmptyApplicationsState(
              onBrowseJobs: () => context.go('/home'),
            );
          }

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Gradient header ──
              SliverToBoxAdapter(
                child: _ApplicationsHeader(
                  count: page.items.length,
                  applied: page.items
                      .where((a) => a.status == ApplicationStatus.applied)
                      .length,
                  accepted: page.items
                      .where((a) => a.status == ApplicationStatus.accepted)
                      .length,
                ),
              ),

              // ── Cards ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final app = page.items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ApplicationCard(
                          application: app,
                          statusColor: _statusColor(app.status, colors),
                          avatarGradient: _avatarGradient(app.status, colors),
                          statusBgColor: _statusBgColor(app.status, colors),
                          statusIcon: _statusIcon(app.status),
                          statusLabel: _statusLabel(app.status),
                          initials: _initials(app.companyName ?? ''),
                          onTap: () => context.push(
                            '/applications/${app.id}',
                            extra: app,
                          ),
                        ),
                      );
                    },
                    childCount: page.items.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Gradient header with summary stats ──

class _ApplicationsHeader extends StatelessWidget {
  const _ApplicationsHeader({
    required this.count,
    required this.applied,
    required this.accepted,
  });

  final int count;
  final int applied;
  final int accepted;

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
          bottom: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => context.pop(),
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
                    'My Applications',
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
              const SizedBox(height: 4),

              // Title + count
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        count == 1 ? 'Application' : 'Applications',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Mini stats
                  _HeaderStat(
                    icon: Icons.send_rounded,
                    label: 'Applied',
                    value: '$applied',
                  ),
                  const SizedBox(width: 20),
                  _HeaderStat(
                    icon: Icons.celebration_rounded,
                    label: 'Accepted',
                    value: '$accepted',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.75),
          ),
        ),
      ],
    );
  }
}

// ── Application card ──

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.statusColor,
    required this.avatarGradient,
    required this.statusBgColor,
    required this.statusIcon,
    required this.statusLabel,
    required this.initials,
    required this.onTap,
  });

  final Application application;
  final Color statusColor;
  final Gradient avatarGradient;
  final Color statusBgColor;
  final IconData statusIcon;
  final String statusLabel;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Company avatar (status-colored gradient)
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: avatarGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              /// Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.jobTitle ?? 'Job',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application.companyName ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        /// Status chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 5),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        /// Applied date
                        if (application.appliedAt != null)
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_outlined,
                                  size: 12,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    DateFormat('d MMM yyyy')
                                        .format(application.appliedAt!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              /// Arrow
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shimmer loading state ──

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _Shimmer(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 96,
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(4, (_) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer({
    required this.child,
    required this.baseColor,
    required this.highlightColor,
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, t, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final dx = rect.width * (t * 2 - 1);
            return LinearGradient(
              begin: Alignment(dx - 0.5, 0),
              end: Alignment(dx + 0.5, 0),
              colors: [baseColor, highlightColor, baseColor],
            ).createShader(rect);
          },
          child: child,
        );
      },
      onEnd: () {},
      child: child,
    );
  }
}

// ── Empty state ──

class _EmptyApplicationsState extends StatelessWidget {
  const _EmptyApplicationsState({required this.onBrowseJobs});

  final VoidCallback onBrowseJobs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary.withOpacity(0.15),
                  colors.primary.withOpacity(0.03),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 72,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No applications yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start applying to jobs and track all your applications here in one place.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onBrowseJobs,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text(
                'Browse Jobs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}