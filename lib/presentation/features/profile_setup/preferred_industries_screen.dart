import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/widgets/chip_group.dart';
import 'package:scn_jobs/presentation/features/profile_setup/profile_setup_controller.dart';
import 'package:scn_jobs/presentation/providers/master/master_providers.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';
import 'package:scn_jobs/presentation/shared_widgets/empty_state.dart';

/// Last of the four preference screens — completing this advances the
/// stepper past "preferences" and moves to `/profile-setup/resume`
/// (Day 13).
class PreferredIndustriesScreen extends ConsumerStatefulWidget {
  const PreferredIndustriesScreen({super.key});

  @override
  ConsumerState<PreferredIndustriesScreen> createState() =>
      _PreferredIndustriesScreenState();
}

class _PreferredIndustriesScreenState
    extends ConsumerState<PreferredIndustriesScreen> {
  final Set<String> _selected = {};
  // Custom, typed-in industries that aren't in the master list. These
  // are never numeric master ids, so `updatePreferredIndustries` routes
  // them to the doc-confirmed `industryNames` find-or-create field
  // instead of `preferredIndustryIds`.
  final Set<String> _customIndustries = {};
  final TextEditingController _searchController = TextEditingController();
  bool _submitting = false;
  // Same fix as the Skills screen: rendering every industry chip in one
  // `Wrap` at once was what made the whole tree build synchronously
  // before the first frame — paginate instead. Only this many chips
  // are actually built; "Load more" bumps it by the same amount.
  static const _pageSize = 10;
  int _visibleCount = _pageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addCustomIndustry(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _customIndustries.add(trimmed);
      _searchController.clear();
      _visibleCount = _pageSize;
    });
  }

  Future<void> _continue() async {
    // Industries are optional — nothing selected just skips ahead
    // instead of blocking with an error.
    if (_selected.isEmpty && _customIndustries.isEmpty) {
      ref.read(profileSetupControllerProvider.notifier).completeCurrentStep();
      context.push('/profile-setup/resume');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(updatePreferredIndustriesUseCaseProvider)(
        [..._selected, ..._customIndustries],
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ref.read(profileSetupControllerProvider.notifier).completeCurrentStep();
      context.push('/profile-setup/resume');
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
    final industriesAsync = ref.watch(industriesProvider);
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
          'Preferred Industries',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: industriesAsync.when(
        loading: () => const _LoadingState(),
        error: (_, __) => const _ErrorState(),
        data: (industries) {
          if (industries.isEmpty) {
            return const _EmptyState();
          }

          final filtered = _searchController.text.isEmpty
              ? industries
              : industries
              .where((i) => i.name
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()))
              .toList();

          final totalCount = _selected.length + _customIndustries.length;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// Step indicator — FINAL STEP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flag_rounded,
                                  size: 12,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Final Step — 4 of 4',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      /// Header card — celebratory
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
                                Icons.business_center_rounded,
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
                                    'Almost done!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pick industries you want to work in. This is the last step before we show you matching jobs.',
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
                          // Fresh search — start the visible slice over.
                          _visibleCount = _pageSize;
                        }),
                        onSubmitted: (value) {
                          final hasMatch = industries.any((i) => i.name
                              .toLowerCase()
                              .contains(value.trim().toLowerCase()));
                          if (!hasMatch && value.trim().isNotEmpty) {
                            _addCustomIndustry(value);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Search industries...',
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
                                  _customIndustries.clear();
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

                      /// Custom (typed-in) industry chips
                      if (_customIndustries.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _customIndustries.map((industry) {
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
                                      industry,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => setState(() =>
                                          _customIndustries.remove(industry)),
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

                      /// Industry chips
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
                                  'No industries found for "${_searchController.text}"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () => _addCustomIndustry(
                                      _searchController.text),
                                  icon: Icon(Icons.add_rounded,
                                      size: 18, color: colors.primary),
                                  label: Text(
                                    'Add',
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
                              .map((industry) {
                            final isSelected = _selected.contains(industry.id);
                            return _IndustryChip(
                              label: industry.name,
                              isSelected: isSelected,
                              onTap: () => setState(() {
                                if (isSelected) {
                                  _selected.remove(industry.id);
                                } else {
                                  _selected.add(industry.id);
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
/// Industry chip widget
/// ─────────────────────────────────────────────
class _IndustryChip extends StatelessWidget {
  const _IndustryChip({
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
    // Some industry names are quite long (e.g. "Facility Management
    // and Support Services"). Without a width cap the chip just grows
    // to fit the whole label, and inside a `Wrap` a single child wider
    // than the available row overflows to the right instead of
    // wrapping — that's the "RIGHT OVERFLOWED BY n PIXELS" banner.
    // Capping the chip's width and truncating the label with an
    // ellipsis keeps every chip inside the screen.
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
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    child: Text(
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
            'Loading industries...',
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
              "Couldn't load industries",
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
            Icon(Icons.business_center_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No industries available',
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