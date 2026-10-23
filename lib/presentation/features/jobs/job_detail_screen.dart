import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:scn_jobs/domain/entities/job.dart';
import 'package:scn_jobs/domain/usecases/fetch_job_detail_usecase.dart';
import 'package:scn_jobs/presentation/features/applications/applications_controller.dart';
import 'package:scn_jobs/presentation/providers/jobs/job_providers.dart';
import 'package:scn_jobs/presentation/shared_widgets/empty_state.dart';

final jobDetailProvider =
FutureProvider.autoDispose.family<Job, String>((ref, jobId) {
  final useCase = FetchJobDetailUseCase(ref.watch(jobRepositoryProvider));
  return useCase(jobId);
});

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({required this.jobId, super.key});

  final String jobId;

  // STATIC methods so nested widgets can access them
  static String salaryText(Job job) {
    if (!job.hasSalaryRange) return 'Not specified';
    final min = job.salaryMin;
    final max = job.salaryMax;
    final suffix = job.wagePeriodSuffix;
    if (min != null && max != null)
      return '₹${NumberFormat('#,##,###').format(min)} - ₹${NumberFormat('#,##,###').format(max)}$suffix';
    if (min != null) return 'From ₹${NumberFormat('#,##,###').format(min)}$suffix';
    return 'Up to ₹${NumberFormat('#,##,###').format(max)}$suffix';
  }

  static String initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  /// Real relative-time label from `job.postedAt` — replaces the old
  /// hardcoded "Posted 2 days ago" placeholder.
  static String postedAgo(DateTime? postedAt) {
    if (postedAt == null) return 'Recently posted';
    final diff = DateTime.now().difference(postedAt);
    if (diff.inMinutes < 1) return 'Posted just now';
    if (diff.inMinutes < 60) return 'Posted ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Posted ${diff.inHours}h ago';
    final days = diff.inDays;
    if (days < 2) return 'Posted yesterday';
    if (days < 30) return 'Posted $days days ago';
    return 'Posted ${(days / 30).floor()}mo ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobId));
    final colors = Theme.of(context).colorScheme;

    // "Applied" state — derived from the worker's own application list
    // (already fetched for MyApplicationsScreen), not a guess. While
    // that list is still loading/erroring we default to false so the
    // button isn't stuck disabled; the backend itself is still the
    // real source of truth and will reject a duplicate apply if this
    // ever races.
    final applicationsAsync = ref.watch(applicationsControllerProvider);
    final hasApplied = applicationsAsync.maybeWhen(
      data: (page) => page.items.any((a) => a.jobId == jobId),
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: jobAsync.when(
        loading: () => const _DetailSkeleton(),
        error: (_, __) => _ErrorView(jobId: jobId),
        data: (job) => _JobContent(
          job: job,
          jobId: jobId,
          hasApplied: hasApplied,
          colors: colors,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Main Content
// ═══════════════════════════════════════════

class _JobContent extends StatelessWidget {
  const _JobContent({
    required this.job,
    required this.jobId,
    required this.hasApplied,
    required this.colors,
  });

  final Job job;
  final String jobId;
  final bool hasApplied;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final qualsLine = job.qualificationNames.isEmpty
        ? null
        : job.qualificationNames.join(', ');
    final hasRecruiterCard = job.companyName.trim().isNotEmpty &&
        job.companyName != 'Unknown Company';

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            /// Plain white AppBar — back only.
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: InkWell(
                  onTap: () => context.pop(),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, size: 20),
                  ),
                ),
              ),
            ),

            /// Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ══════════ Card 1 — Header ══════════
                    _JobCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  job.title,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _ScnBadge(colors: colors),
                            ],
                          ),
                          const SizedBox(height: 10),

                          /// Posted by
                          Row(
                            children: [
                              Icon(Icons.apartment_rounded,
                                  size: 16, color: colors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Posted by:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  job.companyName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          /// Contact unlocked pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline_rounded,
                                    size: 13, color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(
                                  'Contact unlocked after applying',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          /// Quick facts row
                          Wrap(
                            spacing: 18,
                            runSpacing: 10,
                            children: [
                              if (job.experienceRangeLabel != null)
                                _QuickFact(
                                  icon: Icons.work_outline_rounded,
                                  text: job.experienceRangeLabel!,
                                ),
                              _QuickFact(
                                icon: Icons.currency_rupee_rounded,
                                text: JobDetailScreen.salaryText(job),
                              ),
                              if (job.locationName != null &&
                                  job.locationName!.isNotEmpty)
                                _QuickFact(
                                  icon: Icons.location_on_outlined,
                                  text: job.locationName!,
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Colors.grey.shade100, height: 1),
                          const SizedBox(height: 14),

                          /// Posted ago · openings + Apply
                          Row(
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: JobDetailScreen.postedAgo(
                                            job.postedAt)
                                            .replaceFirst('Posted ', 'Posted: '),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (job.headcountRequired != null) ...[
                                        TextSpan(
                                          text: '   •   ',
                                          style: TextStyle(
                                              color: Colors.grey.shade400),
                                        ),
                                        TextSpan(
                                          text: 'Openings: ',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '${job.headcountRequired}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: hasApplied
                                    ? null
                                    : () => context.push(
                                  '/jobs/$jobId/apply',
                                  extra: job,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  hasApplied ? Colors.grey.shade300 : colors.primary,
                                  foregroundColor:
                                  hasApplied ? Colors.grey.shade600 : Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade200,
                                  disabledForegroundColor: Colors.grey.shade500,
                                  elevation: 0,
                                  // Overrides the app-wide ElevatedButtonTheme's
                                  // `minimumSize: Size(double.infinity, ...)`.
                                  // Without this, this button (which sits in a
                                  // plain Row, not an Expanded/SizedBox like the
                                  // bottom bar's Apply button) asks its parent
                                  // for infinite width and crashes with
                                  // "BoxConstraints forces an infinite width."
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasApplied) ...[
                                      const Icon(Icons.check_circle, size: 15),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(
                                      hasApplied ? 'Applied' : 'Apply',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
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

                    const SizedBox(height: 16),

                    // ══════════ Card 2 — Job Description ══════════
                    _JobCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Job Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Divider(color: Colors.grey.shade100, height: 1),
                          const SizedBox(height: 14),

                          /// Grey summary box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _SummaryLine(
                                  label: 'Location',
                                  value: job.locationName ?? 'Not specified',
                                ),
                                _SummaryLine(
                                  label: 'Experience',
                                  value: job.experienceRangeLabel ??
                                      'Not specified',
                                ),
                                _SummaryLine(
                                  label: 'Job Type',
                                  value: job.jobTypeLabel,
                                ),
                              ],
                            ),
                          ),

                          /// About the Role — only if the backend
                          /// actually sent free text; never invented.
                          if (job.description != null &&
                              job.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Text(
                              'About the Role:',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              job.description!.trim(),
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.55,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],

                          /// Responsibilities — real `responsibilities`
                          /// field. NOT `highlights` (that's a separate
                          /// free-text notes field, confirmed from a raw
                          /// job payload dump on 2026-09-11).
                          if (job.responsibilities.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Text(
                              'Responsibilities:',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...job.responsibilities.map((h) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 7),
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      h,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.5,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],

                          const SizedBox(height: 14),
                          Divider(color: Colors.grey.shade100, height: 1),
                          const SizedBox(height: 14),

                          /// Structured key-value details
                          _DetailKeyValue(label: 'Role', value: job.title),
                          if (job.industryName != null)
                            _DetailKeyValue(
                                label: 'Industry Type',
                                value: job.industryName!),
                          if (job.functionName != null)
                            _DetailKeyValue(
                                label: 'Department / Function',
                                value: job.functionName!),
                          _DetailKeyValue(
                              label: 'Employment Type',
                              value: job.employmentTypeDisplay),
                          _DetailKeyValue(
                              label: 'Working Days',
                              value: job.workingDaysLabel),
                          _DetailKeyValue(
                              label: 'Gender Requirement',
                              value: job.genderLabel),
                          if (job.workingStatusLabel != null)
                            _DetailKeyValue(
                                label: 'Working Status Required',
                                value: job.workingStatusLabel!),
                          _DetailKeyValue(
                            label: 'Fresher Status',
                            value: job.freshersOnly
                                ? 'Freshers Allowed'
                                : 'Experienced Candidates Only',
                            valueColor: job.freshersOnly
                                ? Colors.green.shade700
                                : null,
                            bold: job.freshersOnly,
                          ),

                          if (qualsLine != null) ...[
                            const SizedBox(height: 14),
                            Divider(color: Colors.grey.shade100, height: 1),
                            const SizedBox(height: 14),
                            Text(
                              'EDUCATION & QUALIFICATIONS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Required Qualifications: ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  TextSpan(
                                    text: qualsLine,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (job.skillNames.isNotEmpty ||
                              job.assetNames.isNotEmpty ||
                              job.benefitNames.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Divider(color: Colors.grey.shade100, height: 1),
                            const SizedBox(height: 14),
                            Text(
                              'KEY SKILLS & REQUIRED ASSETS / BENEFITS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            if (job.skillNames.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Skills highlighted with '\u2605' are preferred keyskills",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...job.skillNames.map((s) => _TagChip(
                                  text: '\u2605 $s',
                                  background: Colors.white,
                                  border: Colors.grey.shade300,
                                  textColor: Colors.black87,
                                )),
                                ...job.assetNames.map((a) => _TagChip(
                                  icon: Icons.work_outline_rounded,
                                  text: a,
                                  background: Colors.deepPurple.shade50,
                                  border: Colors.deepPurple.shade100,
                                  textColor: Colors.deepPurple.shade700,
                                )),
                                ...job.benefitNames.map((b) => _TagChip(
                                  icon: Icons.card_giftcard_rounded,
                                  text: b,
                                  background: Colors.green.shade50,
                                  border: Colors.green.shade100,
                                  textColor: Colors.green.shade700,
                                )),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ══════════ Card 3 — Recruiter Details ══════════
                    // Only rendered once we actually have a recruiter
                    // name to show — no placeholder/fake identity.
                    if (hasRecruiterCard) ...[
                      const SizedBox(height: 16),
                      _JobCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.people_alt_outlined,
                                    size: 19, color: colors.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  'Recruiter Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: Colors.grey.shade100, height: 1),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      _CompanyAvatar(
                                        companyName: job.companyName,
                                        colors: colors,
                                        size: 44,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              job.companyName,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Recruiter · SCN Partner Network',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            if (job.recruiterEmail !=
                                                null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                job.recruiterEmail!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                  Colors.grey.shade500,
                                                ),
                                                overflow:
                                                TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  // ✅ Gated on `hasApplied` — previously
                                  // this always rendered the locked
                                  // state regardless of application
                                  // status, so the number could never
                                  // actually unlock. When applied AND
                                  // the backend actually sent a phone
                                  // (`job.recruiterPhone`, confirmed to
                                  // live at `poster.phone` — a raw
                                  // payload dump, 2026-09-11), show it;
                                  // otherwise fall back to a plain
                                  // "not available" note rather than
                                  // silently showing nothing.
                                  if (hasApplied)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.green.shade100),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.call_rounded,
                                              size: 16,
                                              color: Colors.green.shade700),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              job.recruiterPhone ??
                                                  "Contact number not available for this job",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: job.recruiterPhone !=
                                                    null
                                                    ? Colors.green.shade800
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                          if (job.recruiterPhone != null)
                                            InkWell(
                                              onTap: () {
                                                Clipboard.setData(
                                                  ClipboardData(
                                                      text: job
                                                          .recruiterPhone!),
                                                );
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    content: Text(
                                                        'Number copied'),
                                                  ),
                                                );
                                              },
                                              child: Icon(
                                                Icons.copy_rounded,
                                                size: 16,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                        ],
                                      ),
                                    )
                                  else
                                    InkWell(
                                      onTap: () => context.push(
                                        '/jobs/$jobId/apply',
                                        extra: job,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                          BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.lock_outline_rounded,
                                                size: 15,
                                                color: Colors.grey.shade600),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Apply to view recruiter's contact number",
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    /// Tips
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lightbulb_rounded,
                              size: 18,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pro Tip',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add a cover note to stand out. Recruiters are 3x more likely to respond to personalized applications.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade700,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        /// Sticky Bottom Bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade100),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  /// Apply Button
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: hasApplied
                            ? null
                            : () => context.push(
                          '/jobs/$jobId/apply',
                          extra: job,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          hasApplied ? Colors.grey.shade300 : colors.primary,
                          foregroundColor:
                          hasApplied ? Colors.grey.shade600 : Colors.white,
                          disabledBackgroundColor: Colors.grey.shade200,
                          disabledForegroundColor: Colors.grey.shade500,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          shadowColor: colors.primary.withOpacity(0.4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              hasApplied ? 'Applied' : 'Apply Now',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              hasApplied
                                  ? Icons.check_circle
                                  : Icons.arrow_forward_rounded,
                              size: 22,
                            ),
                          ],
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
    );
  }
}

// ═══════════════════════════════════════════
// Components
// ═══════════════════════════════════════════

class _JobCard extends StatelessWidget {
  const _JobCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Generic platform badge shown in the header — used instead of a
/// per-job company logo, since neither a company name nor a logo URL
/// is a confirmed field on `GET /jobs/:id` (see `Job.companyName`'s
/// doc — it's actually the recruiter's name, defensively resolved).
class _ScnBadge extends StatelessWidget {
  const _ScnBadge({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/final.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            Icon(Icons.work_rounded, size: 20, color: colors.primary),
      ),
    );
  }
}

class _QuickFact extends StatelessWidget {
  const _QuickFact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailKeyValue extends StatelessWidget {
  const _DetailKeyValue({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.text,
    required this.background,
    required this.border,
    required this.textColor,
    this.icon,
  });

  final String text;
  final Color background;
  final Color border;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyAvatar extends StatelessWidget {
  const _CompanyAvatar({
    required this.companyName,
    required this.colors,
    this.size = 64,
  });

  final String companyName;
  final ColorScheme colors;
  final double size;

  String get _initials =>
      JobDetailScreen.initials(companyName);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            colors.primary.withBlue((colors.primary.blue * 0.75).round()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Error State
// ═══════════════════════════════════════════

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: colors.error,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Couldn't load job",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Something went wrong while loading this job. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(jobDetailProvider(jobId)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Skeleton Loader
// ═══════════════════════════════════════════

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header area
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 140,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Container(
            width: double.infinity,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 24),

          // Info grid skeleton
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 24),

          // Sections
          ...List.generate(
            3,
                (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
