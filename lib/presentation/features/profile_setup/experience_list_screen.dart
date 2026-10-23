import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:scn_jobs/core/error/api_failure.dart';
import 'package:scn_jobs/domain/entities/experience.dart';
import 'package:scn_jobs/presentation/features/profile_setup/profile_setup_controller.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';

class ExperienceListScreen extends ConsumerStatefulWidget {
  const ExperienceListScreen({super.key});

  @override
  ConsumerState<ExperienceListScreen> createState() =>
      _ExperienceListScreenState();
}

class _ExperienceListScreenState extends ConsumerState<ExperienceListScreen> {
  late Future<List<Experience>> _future;
  final _dateFormat = DateFormat('MMM yyyy');
  bool _markingFresher = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(experienceRepositoryProvider).list();
  }

  void _refresh() {
    setState(() {
      _future = ref.read(experienceRepositoryProvider).list();
    });
  }

  Future<void> _addNew() async {
    final added = await context.push<bool>('/profile-setup/experience/add');
    if (added ?? false) _refresh();
  }

  void _continue() {
    ref.read(profileSetupControllerProvider.notifier).completeCurrentStep();
    context.push('/profile-setup/preferences/skills');
  }

  /// "I'm a Fresher" — shown right on this list screen, next to the Add
  /// Experience button, so someone with no work history never has to
  /// open the add-experience form just to say so. Marks the profile
  /// and moves straight to the next step.
  Future<void> _markAsFresher() async {
    if (_markingFresher) return;
    setState(() => _markingFresher = true);
    try {
      await ref.read(updateWorkingStatusUseCaseProvider)(isFresher: true);
      if (mounted) {
        HapticFeedback.lightImpact();
        ref.read(profileSetupControllerProvider.notifier).completeCurrentStep();
        context.push('/profile-setup/preferences/skills');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiFailure ? e.message : "Couldn't save. Try again.",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingFresher = false);
    }
  }

  Future<void> _deleteExperience(Experience exp) async {
    try {
      await ref.read(removeExperienceUseCaseProvider)(exp.id);
      _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't remove — try again")),
        );
      }
    }
  }

  String _dateRange(Experience exp) {
    final start = _dateFormat.format(exp.startDate);
    final end = exp.isCurrent ? 'Present' : _dateFormat.format(exp.endDate!);
    return '$start – $end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
            child: const Icon(Icons.arrow_back, size: 20),
          ),
        ),
        title: const Text(
          'Work Experience',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Experience>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingState();
          }

          final items = snapshot.data ?? const [];

          return Column(
            children: [
              Expanded(
                child: items.isEmpty
                    ? _EmptyState(
                  onAdd: _addNew,
                  onFresher: _markAsFresher,
                  markingFresher: _markingFresher,
                )
                    : _ExperienceList(
                  items: items,
                  dateRange: _dateRange,
                  onRefresh: _refresh,
                  onDelete: _deleteExperience,
                ),
              ),
              _BottomActions(
                itemsCount: items.length,
                onAdd: _addNew,
                onContinue: _continue,
              ),
            ],
          );
        },
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
            height: 40,
            width: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your experience...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Empty state
/// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onAdd,
    required this.onFresher,
    required this.markingFresher,
  });

  final VoidCallback onAdd;
  final VoidCallback onFresher;
  final bool markingFresher;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          /// Step indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step 4 of 4',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ),

          const SizedBox(height: 48),

          /// Illustration
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
              Icons.work_outline_rounded,
              size: 72,
              color: colors.primary,
            ),
          ),

          const SizedBox(height: 32),

          /// Headline
          Text(
            'Add work experience',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 10),

          /// Subtitle
          Text(
            "Don't worry if this is your first job — you can skip this step. "
                'Add any past work to help recruiters see your background.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 36),

          /// Add button
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text(
                'Add Experience',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          /// "I'm a Fresher" — right here on the same screen as the
          /// Add Experience button, so no one has to open the form
          /// just to say they have no work history.
          InkWell(
            onTap: markingFresher ? null : onFresher,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_objects_outlined,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "I'm a Fresher",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        Text(
                          "I don't have any work experience yet",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  markingFresher
                      ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.blue.shade700,
                    ),
                  )
                      : Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Experience list with cards
/// ─────────────────────────────────────────────
class _ExperienceList extends StatelessWidget {
  const _ExperienceList({
    required this.items,
    required this.dateRange,
    required this.onRefresh,
    required this.onDelete,
  });

  final List<Experience> items;
  final String Function(Experience) dateRange;
  final VoidCallback onRefresh;
  final ValueChanged<Experience> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: colors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          /// Step indicator
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
                  'Step 4 of 4',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// Section header
          Row(
            children: [
              Text(
                'Your Experience',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// List of experience cards
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final exp = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ExperienceCard(
                experience: exp,
                dateRange: dateRange(exp),
                index: index,
                onDelete: () => onDelete(exp),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Single experience card
/// ─────────────────────────────────────────────
class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.experience,
    required this.dateRange,
    required this.index,
    required this.onDelete,
  });

  final Experience experience;
  final String dateRange;
  final int index;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('exp_${experience.id}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: Colors.red.shade400),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary.withOpacity(0.15),
                    colors.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.work_rounded,
                size: 24,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 14),

            /// Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    experience.jobTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    experience.companyName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: dateRange,
                      ),
                      if (experience.isCurrent)
                        _PresentChip(),
                    ],
                  ),
                  if (experience.description != null &&
                      experience.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      experience.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Present badge
/// ─────────────────────────────────────────────
class _PresentChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.green.shade500,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Present',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Info chip (date range)
/// ─────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Bottom sticky actions
/// ─────────────────────────────────────────────
class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.itemsCount,
    required this.onAdd,
    required this.onContinue,
  });

  final int itemsCount;
  final VoidCallback onAdd;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (itemsCount > 0)
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onAdd,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Add more experience',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (itemsCount > 0) const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Row(
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
            if (itemsCount == 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Text(
                    'This step is optional — you can add experience later',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
