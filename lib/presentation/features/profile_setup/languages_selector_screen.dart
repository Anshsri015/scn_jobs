import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/widgets/chip_group.dart';
import 'package:scn_jobs/domain/entities/language_selection.dart';
import 'package:scn_jobs/presentation/providers/master/master_providers.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';
import 'package:scn_jobs/presentation/shared_widgets/empty_state.dart';

/// Each selected language also carries a [LanguageProficiency]. Picking
/// a language opens a bottom sheet to choose the proficiency — the
/// language is only added to [_selected] once the worker taps "OK" in
/// that sheet, so the screen never fills up with a growing stack of
/// per-language proficiency rows. Tapping an already-selected chip
/// reopens the same sheet to change its proficiency (or remove it).
class LanguagesSelectorScreen extends ConsumerStatefulWidget {
  const LanguagesSelectorScreen({super.key});

  @override
  ConsumerState<LanguagesSelectorScreen> createState() =>
      _LanguagesSelectorScreenState();
}

class _LanguagesSelectorScreenState
    extends ConsumerState<LanguagesSelectorScreen> {
  final Map<String, LanguageProficiency> _selected = {};
  final TextEditingController _searchController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    // Languages are optional — nothing selected just skips ahead
    // instead of blocking with an error.
    if (_selected.isEmpty) {
      context.push('/profile-setup/preferences/industries');
      return;
    }
    setState(() => _submitting = true);
    try {
      final selections = _selected.entries
          .map((e) =>
          LanguageSelection(languageId: e.key, proficiency: e.value))
          .toList();
      await ref.read(updateLanguagesUseCaseProvider)(selections);
      if (mounted) {
        HapticFeedback.lightImpact();
        // Preferred-locations step removed from the flow — go straight
        // to industries.
        context.push('/profile-setup/preferences/industries');      }
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

  /// Opens a bottom sheet to pick (or change) the proficiency for
  /// [langId]/[langName]. Nothing changes in [_selected] until the
  /// worker taps "OK" — dismissing the sheet any other way (back
  /// button, tapping outside) leaves the previous selection untouched.
  /// When [langId] is already selected, an extra "Remove" action is
  /// shown so the worker can deselect it from the same sheet.
  Future<void> _openProficiencySheet(String langId, String langName) async {
    final current = _selected[langId];
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProficiencySheet(
        languageName: langName,
        initialValue: current ?? LanguageProficiency.intermediate,
        showRemove: current != null,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result == _removeLanguageSentinel) {
        _selected.remove(langId);
      } else if (result is LanguageProficiency) {
        _selected[langId] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final languagesAsync = ref.watch(languagesProvider);
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
          'Languages',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: languagesAsync.when(
        loading: () => const _LoadingState(),
        error: (_, __) => const _ErrorState(),
        data: (languages) {
          if (languages.isEmpty) {
            return const _EmptyState();
          }

          final filtered = _searchController.text.isEmpty
              ? languages
              : languages
              .where((l) => l.name
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()))
              .toList();

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
                              'Preferences 2 of 4',
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
                                Icons.translate_rounded,
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
                                    'Languages you speak',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Select all languages you can communicate in. This helps employers match you with the right jobs.',
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
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search languages...',
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
                              setState(() {});
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
                      if (_selected.isNotEmpty)
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
                                  '${_selected.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _selected.clear()),
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

                      /// Language chips
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
                                  'No languages found for "${_searchController.text}"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
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
                          children: filtered.map((lang) {
                            final isSelected = _selected.containsKey(lang.id);
                            return _LanguageChip(
                              label: lang.name,
                              isSelected: isSelected,
                              proficiencyLabel: isSelected
                                  ? _selected[lang.id]!.label
                                  : null,
                              onTap: () =>
                                  _openProficiencySheet(lang.id, lang.name),
                            );
                          }).toList(),
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
                            _selected.isEmpty
                                ? 'Skip for now'
                                : 'Continue (${_selected.length})',
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
/// Language chip widget
/// ─────────────────────────────────────────────
class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.proficiencyLabel,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Shown as a small subtitle under [label] once this language is
  /// selected (e.g. "Intermediate"). Null when not selected.
  final String? proficiencyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Same cap as Industries/Skills chips — long language names
    // shouldn't push the chip past the screen width inside the Wrap.
    final maxChipWidth = MediaQuery.of(context).size.width - 56;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: AnimatedContainer(
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
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : colors.primary,
                          ),
                        ),
                        if (proficiencyLabel != null)
                          Text(
                            proficiencyLabel!,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.85),
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
      ),
    );
  }
}

/// Sentinel value returned by [_ProficiencySheet] when the worker taps
/// "Remove" — distinct from `null` (dismissed / no change) and from any
/// [LanguageProficiency] value (confirmed pick).
const Object _removeLanguageSentinel = Object();

/// ─────────────────────────────────────────────
/// Proficiency picker bottom sheet
/// ─────────────────────────────────────────────
/// Shown when a language is tapped. Nothing is added/changed in the
/// caller's selection map until "OK" is pressed here — this is what
/// keeps the language list on the main screen from filling up with a
/// per-language proficiency row for every pick; the worker picks a
/// level and confirms before moving on to the next language.
class _ProficiencySheet extends StatefulWidget {
  const _ProficiencySheet({
    required this.languageName,
    required this.initialValue,
    required this.showRemove,
  });

  final String languageName;
  final LanguageProficiency initialValue;
  final bool showRemove;

  @override
  State<_ProficiencySheet> createState() => _ProficiencySheetState();
}

class _ProficiencySheetState extends State<_ProficiencySheet> {
  late LanguageProficiency _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.languageName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  'How well do you speak this language?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),

                /// Plain list of proficiency levels — a checkmark on the
                /// left of the selected row, bold black text throughout,
                /// no background/border boxes.
                ...LanguageProficiency.values.map((level) {
                  final isSelected = level == _value;
                  return InkWell(
                    onTap: () => setState(() => _value = level),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: isSelected
                                ? const Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: Colors.black87,
                            )
                                : null,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${level.label} ${widget.languageName}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),
                if (widget.showRemove)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_removeLanguageSentinel),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                      ),
                      child: const Text(
                        'Remove this language',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_value),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'OK',
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
            'Loading languages...',
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
              "Couldn't load languages",
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
            Icon(Icons.translate_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No languages available',
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
