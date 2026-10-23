import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scn_jobs/domain/entities/education.dart';
import 'package:scn_jobs/domain/entities/master_data.dart' show QualificationItem;
import 'package:scn_jobs/presentation/features/profile_setup/education_form_screen.dart'
    show kEducationLevels;
import 'package:scn_jobs/presentation/features/profile_setup/profile_setup_controller.dart';
import 'package:scn_jobs/presentation/providers/master/master_providers.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';

/// Level enum -> screenshot display label (e.g. "GRADUATE" -> "Graduate").
String _levelLabel(String level) {
  for (final l in kEducationLevels) {
    if (l.value == level) return l.label;
  }
  return level;
}

/// The `/worker/education` response never echoes `qualificationName`
/// back (see `EducationModel`'s doc), so after any reload an entry
/// only carries `qualificationId` — showing that raw id ("1165") as
/// the title is what actually looked like "didn't save". Resolving it
/// against the flat `qualificationsProvider` list (matched by id,
/// *not* scoped to `education.level`) also self-corrects the level if
/// the backend ever echoes that back wrong, since ids are unique
/// across every level.
QualificationItem? _matchQualification(
    List<QualificationItem> quals, Education edu) {
  final id = edu.qualificationId;
  if (id == null) return null;
  for (final q in quals) {
    if (q.id == id) return q;
  }
  return null;
}

class EducationListScreen extends ConsumerStatefulWidget {
  const EducationListScreen({super.key});

  @override
  ConsumerState<EducationListScreen> createState() =>
      _EducationListScreenState();
}

class _EducationListScreenState extends ConsumerState<EducationListScreen> {
  late Future<List<Education>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(educationRepositoryProvider).list();
  }

  void _refresh() {
    setState(() {
      _future = ref.read(educationRepositoryProvider).list();
    });
  }

  Future<void> _addNew() async {
    final added = await context.push<bool>('/profile-setup/education/add');
    if (added ?? false) _refresh();
  }

  Future<void> _editEducation(Education edu) async {
    final updated = await context.push<bool>(
      '/profile-setup/education/edit',
      extra: edu,
    );
    if (updated ?? false) _refresh();
  }

  void _continue() {
    ref.read(profileSetupControllerProvider.notifier).completeCurrentStep();
    context.push('/profile-setup/experience');
  }

  Future<void> _deleteEducation(Education edu) async {
    try {
      await ref.read(removeEducationUseCaseProvider)(edu.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't delete. Try again.")),
        );
      }
    } finally {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quals = ref.watch(qualificationsProvider).value ??
        const <QualificationItem>[];

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
          'Education',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Education>>(
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
                    ? _EmptyState(onAdd: _addNew, onSkip: _continue)
                    : _EducationList(
                  items: items,
                  qualifications: quals,
                  onRefresh: _refresh,
                  onDelete: _deleteEducation,
                  onEdit: _editEducation,
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
            'Loading your education...',
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
  const _EmptyState({required this.onAdd, required this.onSkip});

  final VoidCallback onAdd;
  final VoidCallback onSkip;

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
              'Step 3 of 4',
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
              Icons.school_outlined,
              size: 72,
              color: colors.primary,
            ),
          ),

          const SizedBox(height: 32),

          /// Headline
          Text(
            'Add your education',
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
            'Tell us about your qualifications. This helps recruiters understand your background and match you with relevant jobs.',
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
                'Add Education',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          /// Skip text — actually moves to the next step (education is
          /// optional), not another route into the add-form.
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade500,
            ),
            child: const Text(
              'You can add this later',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Education list with cards
/// ─────────────────────────────────────────────
class _EducationList extends StatelessWidget {
  const _EducationList({
    required this.items,
    required this.qualifications,
    required this.onRefresh,
    required this.onDelete,
    required this.onEdit,
  });

  final List<Education> items;
  final List<QualificationItem> qualifications;
  final VoidCallback onRefresh;
  final ValueChanged<Education> onDelete;
  final ValueChanged<Education> onEdit;

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
                  'Step 3 of 4',
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
                'Your Qualifications',
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

          /// List of education cards
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final edu = entry.value;
            final matched = _matchQualification(qualifications, edu);
            // Correct the record before handing it to the edit form —
            // the raw entry may carry a stale/missing level and a
            // null qualificationName (see `_matchQualification`'s
            // doc); without this the edit screen opens on the wrong
            // level with a blank qualification name.
            final editEdu = matched == null
                ? edu
                : edu.copyWith(
              level: matched.level,
              qualificationName: edu.qualificationName ?? matched.name,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EducationCard(
                education: edu,
                index: index,
                qualification: matched,
                onDelete: () => onDelete(edu),
                onEdit: () => onEdit(editEdu),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Single education card
/// ─────────────────────────────────────────────
class _EducationCard extends StatelessWidget {
  const _EducationCard({
    required this.education,
    required this.index,
    required this.qualification,
    required this.onDelete,
    required this.onEdit,
  });

  final Education education;
  final int index;

  /// The matching master-data `QualificationItem`, resolved by id —
  /// used as a fallback for both the display name and the level when
  /// the server response doesn't carry `qualificationName` (see
  /// `_matchQualification`'s doc).
  final QualificationItem? qualification;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final displayLevel = qualification?.level ?? education.level;
    final displayName = education.qualificationName ??
        qualification?.name ??
        education.qualificationId ??
        _levelLabel(displayLevel);

    return Dismissible(
      key: ValueKey('edu_${education.id}_$index'),
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
                Icons.school_rounded,
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
                    displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  if (education.institute != null &&
                      education.institute!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      education.institute!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.stairs_outlined,
                        label: _levelLabel(displayLevel),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            /// Edit icon
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: Colors.grey.shade400,
              ),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Info chip (year / score)
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
                    'Add more education',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (itemsCount > 0) const SizedBox(height: 12),
            // Education is optional (see header "Education (Optional)" in
            // the confirmed design) — Continue must always be enabled,
            // unlike the old build which blocked progress at 0 items.
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      itemsCount > 0 ? 'Continue' : 'Skip for now',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Colors.white,
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
