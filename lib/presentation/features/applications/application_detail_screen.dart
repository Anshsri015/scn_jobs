import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:scn_jobs/domain/entities/application.dart';
import 'package:scn_jobs/domain/entities/application_status.dart';
import 'package:scn_jobs/presentation/features/applications/applications_controller.dart';
import 'package:scn_jobs/presentation/features/applications/widgets/status_timeline.dart';

class ApplicationDetailScreen extends ConsumerStatefulWidget {
  const ApplicationDetailScreen({required this.application, super.key});

  final Application application;

  @override
  ConsumerState<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState
    extends ConsumerState<ApplicationDetailScreen> {
  bool _withdrawing = false;

  Future<void> _confirmWithdraw() async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, color: colors.error),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Withdraw application?'),
            ),
          ],
        ),
        content: const Text(
          "You can't undo this. You would need to apply again if you change your mind.",
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _withdrawing = true);
    try {
      await ref
          .read(applicationsControllerProvider.notifier)
          .withdraw(widget.application.id);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text("Couldn't withdraw. Try again."),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  // ── Status presentation helpers ──

  Color _statusColor(ApplicationStatus status, ColorScheme colors) {
    return switch (status) {
      ApplicationStatus.applied => colors.primary,
      ApplicationStatus.accepted => Colors.green.shade600,
      ApplicationStatus.rejected => colors.error,
    };
  }

  Gradient _statusGradient(ApplicationStatus status, ColorScheme colors) {
    return switch (status) {
      ApplicationStatus.applied => LinearGradient(
        colors: [colors.primary, colors.primary.withOpacity(0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      ApplicationStatus.accepted => LinearGradient(
        colors: [Colors.green.shade500, Colors.teal.shade500],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      ApplicationStatus.rejected => LinearGradient(
        colors: [colors.error, Colors.red.shade300],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    };
  }

  IconData _statusIcon(ApplicationStatus status) {
    return switch (status) {
      ApplicationStatus.applied => Icons.send_rounded,
      ApplicationStatus.accepted => Icons.celebration_rounded,
      ApplicationStatus.rejected => Icons.cancel_rounded,
    };
  }

  String _statusLabel(ApplicationStatus status) {
    return switch (status) {
      ApplicationStatus.applied => 'Applied',
      ApplicationStatus.accepted => 'Accepted',
      ApplicationStatus.rejected => 'Not selected',
    };
  }

  String _initials(String name) {
    final parts =
    name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(app.status, colors);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Hero header ──
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: _statusGradient(app.status, colors),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Back button
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
                            'Application Status',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          // Invisible placeholder to keep the title centered
                          Opacity(
                            opacity: 0,
                            child: IconButton(
                              onPressed: null,
                              icon: const SizedBox(width: 34, height: 34),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Company avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _initials(app.companyName ?? 'C'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Job title
                      Text(
                        app.jobTitle ?? 'Job Position',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        app.companyName ?? 'Company',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _statusIcon(app.status),
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _statusLabel(app.status).toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body content ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Meta info card
                  _MetaCard(
                    appliedAt: app.appliedAt,
                    status: app.status,
                    statusLabel: _statusLabel(app.status),
                    statusColor: statusColor,
                  ),

                  const SizedBox(height: 16),

                  // Progress card
                  _CardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timeline_rounded,
                                size: 20, color: colors.primary),
                            const SizedBox(width: 8),
                            const Text(
                              'Application Progress',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        StatusTimeline(status: app.status),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Withdraw section ──
                  if (app.canWithdraw)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.error.withOpacity(0.2),
                        ),
                        color: colors.error.withOpacity(0.04),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: colors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'You can withdraw this application at any time before a decision is made.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _withdrawing ? null : _confirmWithdraw,
                            icon: _withdrawing
                                ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.logout_rounded, size: 20),
                            label: Text(
                              _withdrawing
                                  ? 'Withdrawing...'
                                  : 'Withdraw Application',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.error,
                              side: BorderSide(
                                color: colors.error.withOpacity(0.4),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This application can no longer be withdrawn.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
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

// ── Reusable card container with soft shadow ──

class _CardContainer extends StatelessWidget {
  const _CardContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

// ── Meta information card ──

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.appliedAt,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
  });

  final DateTime appliedAt;
  final ApplicationStatus status;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Column(
        children: [
          _MetaRow(
            icon: Icons.calendar_today_outlined,
            label: 'Applied on',
            value: DateFormat('d MMM yyyy').format(appliedAt),
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade100),
          const SizedBox(height: 4),
          _MetaRow(
            icon: Icons.flag_outlined,
            label: 'Current status',
            value: statusLabel,
            valueColor: statusColor,
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}