import 'package:flutter/material.dart';

import 'package:scn_jobs/domain/entities/application_status.dart';

/// ✅ Rebuilt for the post-revamp 2-outcome lifecycle: Applied is
/// always step one; the application then either sits at "Applied"
/// (still pending), or resolves to "Accepted" or "Rejected" — there's
/// no in-between stage to show a linear multi-step path for anymore.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({required this.status, super.key});

  final ApplicationStatus status;

  static const _labels = {
    ApplicationStatus.applied: 'Applied',
    ApplicationStatus.accepted: 'Accepted',
    ApplicationStatus.rejected: 'Not selected',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return switch (status) {
      ApplicationStatus.applied => _buildPendingMarker(theme),
      ApplicationStatus.accepted => _buildResolvedMarker(
          theme,
          icon: Icons.check_circle_outline,
          color: Colors.green.shade600,
        ),
      ApplicationStatus.rejected => _buildResolvedMarker(
          theme,
          icon: Icons.cancel_outlined,
          color: theme.colorScheme.error,
        ),
    };
  }

  Widget _buildPendingMarker(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.hourglass_top_rounded, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(_labels[status]!, style: theme.textTheme.titleMedium),
        const SizedBox(width: 8),
        Text(
          '· waiting for recruiter',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildResolvedMarker(
    ThemeData theme, {
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(_labels[status]!, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
