import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scn_jobs/domain/entities/job.dart';

class JobCard extends StatelessWidget {
  const JobCard({
    required this.job,
    required this.onTap,
    this.isSaved = false,
    this.onSaveToggle,
    super.key,
  });

  final Job job;
  final VoidCallback onTap;
  final bool isSaved;
  final ValueChanged<bool>? onSaveToggle;

  String _postedAgo() {
    final postedAt = job.postedAt;
    if (postedAt == null) return '';
    final days = DateTime.now().difference(postedAt).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) return '${(days / 7).floor()}w ago';
    return '${(days / 30).floor()}mo ago';
  }

  bool get _isNew {
    final postedAt = job.postedAt;
    if (postedAt == null) return false;
    return DateTime.now().difference(postedAt).inDays <= 2;
  }

  String _salaryText() {
    if (!job.hasSalaryRange) return 'Not disclosed';
    final min = job.salaryMin;
    final max = job.salaryMax;
    final suffix = job.wagePeriodSuffix;
    final fmt = NumberFormat('#,##,###');
    if (min != null && max != null) {
      return '₹${fmt.format(min)} - ₹${fmt.format(max)}$suffix';
    }
    if (min != null) return 'From ₹${fmt.format(min)}$suffix';
    return 'Up to ₹${fmt.format(max)}$suffix';
  }

  String _initials() {
    final name = job.companyName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final posted = _postedAgo();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: colors.primary.withOpacity(0.05),
          highlightColor: colors.primary.withOpacity(0.02),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// ── Top Row: Avatar + Title + Save ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Company Avatar — app logo, falls back to a flat
                    /// initials badge if the asset is ever missing.
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/final.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Text(
                          _initials(),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    /// Title & Company
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_isNew) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: Colors.green.shade100,
                                    ),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green.shade700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  job.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            job.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// Save Button — simple icon, no filled circle
                    if (onSaveToggle != null)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onSaveToggle!(!isSaved),
                          borderRadius: BorderRadius.circular(50),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              isSaved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              size: 22,
                              color: isSaved
                                  ? colors.primary
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                /// ── Meta Row: Location + Time + Openings ──
                // WHY WRAP INSTEAD OF ROW: the old Row only wrapped the
                // *location* chip in Flexible. The time/openings chips
                // were fixed-size, so when location was long AND those
                // two fixed chips alone already needed more width than
                // the card had, the Row overflowed — Flexible can't
                // rescue a Row when its non-flexible siblings are what's
                // too wide. Wrap removes the failure mode entirely: if a
                // chip doesn't fit on the line, it drops to the next
                // line instead of overflowing, no matter how long the
                // location string or how narrow the phone is.
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (job.locationName != null)
                      ConstrainedBox(
                        // Cap the location chip so it can't claim the
                        // whole line and push time/openings onto their
                        // own row every single time.
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.45,
                        ),
                        child: _MetaChip(
                          icon: Icons.location_on_outlined,
                          text: job.locationName!,
                        ),
                      ),
                    if (posted.isNotEmpty)
                      _MetaChip(
                        icon: Icons.access_time_rounded,
                        text: posted,
                        isTime: true,
                      ),
                    if (job.headcountRequired != null)
                      _MetaChip(
                        icon: Icons.people_outline_rounded,
                        text: '${job.headcountRequired} openings',
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                /// ── Bottom Row: Salary + Job Type ──
                Row(
                  children: [
                    /// Salary Chip — flat, no gradient
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 13,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                // WHY: `_salaryText()` already appends
                                // `job.wagePeriodSuffix` (e.g.
                                // "/month") — the old code tacked on a
                                // second, redundant " /mo" here, which
                                // combined with the unconstrained Row
                                // below is what pushed this chip past
                                // the card's width and triggered the
                                // yellow/black RenderFlex overflow
                                // stripes on narrow phones.
                                _salaryText(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    /// Job Type Chip — flat
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Text(
                          job.employmentTypeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    /// Arrow — no longer wrapped in `Spacer()`, since a
                    /// `Spacer` demands infinite available width from
                    /// the `Row`, which is exactly what breaks once the
                    /// two `Flexible` chips above are already using all
                    /// the space on a narrow screen.
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
    this.isTime = false,
  });

  final IconData icon;
  final String text;
  final bool isTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isTime ? Colors.grey.shade400 : Colors.grey.shade500,
        ),
        const SizedBox(width: 4),
        // Flexible so `overflow: TextOverflow.ellipsis` below actually
        // has something to bite on. Without it, a Row with
        // mainAxisSize.min hands this Text unbounded width, the
        // ellipsis never triggers, and the Row just demands however
        // much space the full string needs — which is exactly what
        // overflowed the parent when a chip was placed inside a
        // width-capped box (e.g. the location chip's ConstrainedBox).
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isTime ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}