import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/widgets/chip_group.dart';
import 'package:scn_jobs/presentation/providers/master/master_providers.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';
import 'package:scn_jobs/presentation/shared_widgets/empty_state.dart';

class SkillsSelectorScreen extends ConsumerStatefulWidget {
  const SkillsSelectorScreen({super.key});

  @override
  ConsumerState<SkillsSelectorScreen> createState() =>
      _SkillsSelectorScreenState();
}

class _SkillsSelectorScreenState extends ConsumerState<SkillsSelectorScreen> {
  final Set<String> _selected = {};
  final Set<String> _customSkills = {};
  final TextEditingController _searchController = TextEditingController();
  bool _submitting = false;
  // Rendering every skill chip in one `Wrap` at once was what froze the
  // loader on accounts with a big skills master list — the whole tree
  // built synchronously before the first frame could show. Paginate
  // instead: only this many chips are actually built; "Load more" bumps
  // it by the same amount.
  static const _pageSize = 10;
  int _visibleCount = _pageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addCustomSkill(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _customSkills.add(trimmed);
      _searchController.clear();
      _visibleCount = _pageSize;
    });
  }

  Future<void> _continue() async {
    // Skills are optional, same as education/experience — nothing
    // selected just skips straight to the next step instead of
    // blocking with an error.
    if (_selected.isEmpty && _customSkills.isEmpty) {
      context.push('/profile-setup/preferences/languages');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(updateSkillsUseCaseProvider)(
        [..._selected, ..._customSkills],
      );
      if (mounted) {
        HapticFeedback.lightImpact();
        context.push('/profile-setup/preferences/languages');
      }
    } catch (_) {
      if (mounted) {
        _showError("Couldn't save. Try again.");
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skillsAsync = ref.watch(skillsProvider);
    final colors = Theme.of(context).colorScheme;

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
          'Your Skills',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: skillsAsync.when(
        loading: () => const _LoadingState(),
        error: (_, __) => const _ErrorState(),
        data: (skills) {
          if (skills.isEmpty) {
            return const _EmptyState();
          }

          /// Filter skills based on search
          final filtered = _searchController.text.isEmpty
              ? skills
              : skills
              .where((s) => s.name
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()))
              .toList();

          final totalCount = _selected.length + _customSkills.length;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// Step indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Preferences 1 of 4',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      /// Header
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
                              color: colors.primary.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.psychology_outlined,
                                color: colors.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select your skills',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pick skills that match your expertise. This helps us show you the most relevant jobs.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// Search bar
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {
                          // New filter → start the pager over so we
                          // don't render hundreds of matches at once.
                          _visibleCount = _pageSize;
                        }),
                        onSubmitted: (value) {
                          final hasMatch = skills.any((s) => s.name
                              .toLowerCase()
                              .contains(value.trim().toLowerCase()));
                          if (!hasMatch && value.trim().isNotEmpty) {
                            _addCustomSkill(value);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Search skills...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.search,
                              color: Colors.grey.shade400),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _visibleCount = _pageSize);
                            },
                            icon: Icon(Icons.close,
                                size: 18, color: Colors.grey.shade500),
                          )
                              : null,
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: colors.primary.withOpacity(0.3),
                                width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Selected count
                      if (totalCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Text(
                                'Selected',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$totalCount',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => setState(() {
                                  _selected.clear();
                                  _customSkills.clear();
                                }),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade400,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Clear all',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                      /// Custom (typed-in) skill chips
                      if (_customSkills.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _customSkills.map((skill) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      skill,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => setState(
                                              () => _customSkills.remove(skill)),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      /// Skills chips
                      if (filtered.isEmpty && _searchController.text.isNotEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.search_off_outlined,
                                    size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'No skills found for "${_searchController.text}"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _addCustomSkill(_searchController.text),
                                  icon: Icon(Icons.add_rounded,
                                      size: 18, color: colors.primary),
                                  label: Text(
                                    'Add "${_searchController.text}" as a skill',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.primary,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: colors.primary.withOpacity(0.3)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: filtered
                              .take(_visibleCount)
                              .map((skill) {
                            final isSelected = _selected.contains(skill.id);
                            return _SkillChip(
                              label: skill.name,
                              isSelected: isSelected,
                              onTap: () => setState(() {
                                if (isSelected) {
                                  _selected.remove(skill.id);
                                } else {
                                  _selected.add(skill.id);
                                }
                              }),
                            );
                          }).toList(),
                        ),

                      /// Load more — only the visible slice above is
                      /// ever built, so this is the only way to reach
                      /// the rest of a long list.
                      if (filtered.length > _visibleCount)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Center(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _visibleCount = (_visibleCount + _pageSize)
                                    .clamp(0, filtered.length);
                              }),
                              icon: Icon(Icons.expand_more_rounded,
                                  size: 18, color: colors.primary),
                              label: Text(
                                'Load more (${filtered.length - _visibleCount} left)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: colors.primary.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              /// Sticky bottom CTA
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        disabledForegroundColor: Colors.grey.shade400,
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            totalCount == 0
                                ? 'Skip for now'
                                : 'Continue ($totalCount)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 20),
                        ],
                      ),
                    ),
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

/// ─────────────────────────────────────────────
/// Skill chip widget
/// ─────────────────────────────────────────────
class _SkillChip extends StatelessWidget {
  const _SkillChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary
                  : colors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : colors.primary.withOpacity(0.15),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            'Loading skills...',
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
/// Error state
/// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "Couldn't load skills",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pull to retry or check your connection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Empty state
/// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No skills available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check back later or contact support.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}