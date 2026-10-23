import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scn_jobs/core/widgets/cascading_location_picker.dart';
import 'package:scn_jobs/core/widgets/chip_group.dart';
import 'package:scn_jobs/presentation/features/jobs/jobs_controller.dart';
import 'package:scn_jobs/presentation/providers/master/master_providers.dart'
    show industriesProvider;

class SearchFilterScreen extends ConsumerStatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  ConsumerState<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends ConsumerState<SearchFilterScreen> {
  final _searchController = TextEditingController();
  final _industrySearchController = TextEditingController();
  Set<String> _selectedLocationIds = {};
  final Set<String> _selectedIndustryIds = {};
  static const _industryPageSize = 10;
  int _industryVisibleCount = _industryPageSize;

  @override
  void initState() {
    super.initState();
    final current = ref.read(jobsControllerProvider.notifier).filter;
    _searchController.text = current.searchQuery ?? '';
    _selectedLocationIds = current.locationIds.toSet();
    _selectedIndustryIds.addAll(current.industryIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _industrySearchController.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.of(context).pop(
      JobsFilter(
        searchQuery: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        locationIds: _selectedLocationIds.toList(),
        industryIds: _selectedIndustryIds.toList(),
      ),
    );
  }

  void _clear() {
    setState(() {
      _searchController.clear();
      _selectedLocationIds.clear();
      _selectedIndustryIds.clear();
      _industrySearchController.clear();
      _industryVisibleCount = _industryPageSize;
    });
  }

  bool get _hasFilters =>
      _searchController.text.trim().isNotEmpty ||
          _selectedLocationIds.isNotEmpty ||
          _selectedIndustryIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final industriesAsync = ref.watch(industriesProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, size: 20),
          ),
        ),
        title: const Text(
          'Filter Jobs',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (_hasFilters)
            TextButton(
              onPressed: _clear,
              child: Text(
                'Clear all',
                style: TextStyle(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            )
          else
            const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Search Field ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            icon: Icons.search_rounded,
                            title: 'Search',
                            colors: colors,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Job title, company, keywords...',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: Colors.grey.shade400,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                              )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                BorderSide(color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: colors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Location Filter ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _SectionHeader(
                                icon: Icons.location_on_outlined,
                                title: 'Location',
                                colors: colors,
                              ),
                              const Spacer(),
                              if (_selectedLocationIds.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_selectedLocationIds.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CascadingLocationPicker(
                            selectedLocalityIds: _selectedLocationIds,
                            onChanged: (updated) =>
                                setState(() => _selectedLocationIds = updated),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Industry Filter ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _SectionHeader(
                                icon: Icons.business_center_outlined,
                                title: 'Industry',
                                colors: colors,
                              ),
                              const Spacer(),
                              if (_selectedIndustryIds.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_selectedIndustryIds.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Search box for industries — same "type to
                          // filter" idea as the location picker, just
                          // inline since industries render as chips
                          // here rather than a bottom sheet.
                          TextField(
                            controller: _industrySearchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search industry',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                              ),
                              suffixIcon:
                              _industrySearchController.text.isNotEmpty
                                  ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                      () => _industrySearchController
                                      .clear(),
                                ),
                              )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: colors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          industriesAsync.when(
                            loading: () => const _IndustrySkeleton(),
                            error: (_, __) => _ErrorChip(
                              message: "Couldn't load industries",
                              onRetry: () =>
                                  ref.invalidate(industriesProvider),
                            ),
                            data: (industries) {
                              final query = _industrySearchController.text
                                  .trim()
                                  .toLowerCase();
                              final isSearching = query.isNotEmpty;
                              final matches = isSearching
                                  ? industries
                                  .where((i) => i.name
                                  .toLowerCase()
                                  .contains(query))
                                  .toList()
                                  : industries;

                              if (isSearching && matches.isEmpty) {
                                return Padding(
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'No industries match "$query"',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }

                              // While actively searching, show every
                              // match instead of the usual 10-at-a-time
                              // page — a search that still needs "Load
                              // more" taps defeats the point of typing
                              // to narrow the list down.
                              final visible = isSearching
                                  ? matches
                                  : matches
                                  .take(_industryVisibleCount)
                                  .toList();
                              final remaining = isSearching
                                  ? 0
                                  : matches.length - _industryVisibleCount;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ChipGroup(
                                    items: visible,
                                    selectedIds: _selectedIndustryIds,
                                    idOf: (i) => i.id,
                                    labelOf: (i) => i.name,
                                    onToggle: (id, selected) => setState(() {
                                      if (selected) {
                                        _selectedIndustryIds.add(id);
                                      } else {
                                        _selectedIndustryIds.remove(id);
                                      }
                                    }),
                                  ),
                                  if (remaining > 0) ...[
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => setState(() {
                                        _industryVisibleCount =
                                            (_industryVisibleCount +
                                                _industryPageSize)
                                                .clamp(0, matches.length);
                                      }),
                                      icon: const Icon(
                                          Icons.expand_more_rounded),
                                      label: Text('Load more ($remaining left)'),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Sticky Bottom Bar ──
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  child: Row(
                    children: [
                      if (_hasFilters) ...[
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: _clear,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: _hasFilters ? 3 : 1,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _apply,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Show Results',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                if (_hasFilters) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_selectedLocationIds.length + _selectedIndustryIds.length + (_searchController.text.isNotEmpty ? 1 : 0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
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
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Components
// ═══════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _ErrorChip extends StatelessWidget {
  const _ErrorChip({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 18, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Retry',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade800,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndustrySkeleton extends StatelessWidget {
  const _IndustrySkeleton();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        6,
            (_) => Container(
          width: 80 + (_.hashCode % 40).toDouble(),
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
