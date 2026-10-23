import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scn_jobs/presentation/features/jobs/jobs_controller.dart';
import 'package:scn_jobs/presentation/features/jobs/widgets/job_card.dart';
import 'package:scn_jobs/presentation/providers/notifications/notifications_providers.dart';
import 'package:scn_jobs/presentation/shared_widgets/empty_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(jobsControllerProvider.notifier).loadMore();
    }
    if (_scrollController.position.pixels > 500 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (_scrollController.position.pixels <= 500 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsControllerProvider);
    final loadingMore = ref.watch(jobsLoadingMoreProvider);
    final filter = ref.watch(jobsControllerProvider.notifier).filter;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                /// ── Simple Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Find your next job',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Consumer(
                            // Own Consumer so a new notification only
                            // rebuilds the bell, not the whole feed.
                            builder: (context, ref, _) {
                              final unread =
                              ref.watch(unreadNotificationsCountProvider);
                              return _HeaderIconButton(
                                icon: Icons.notifications_none_rounded,
                                badge: unread > 0,
                                onTap: () => context.push('/notifications'),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _HeaderIconButton(
                            icon: Icons.settings_outlined,
                            onTap: () => context.push('/settings'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      /// Simple Search Bar
                      InkWell(
                        onTap: () async {
                          final result =
                          await context.push<JobsFilter>('/jobs/filter');
                          if (result != null) {
                            await ref
                                .read(jobsControllerProvider.notifier)
                                .applyFilter(result);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: Colors.grey.shade600,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      filter.isEmpty
                                          ? 'Search jobs, location...'
                                          : 'Tap to edit filters',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: filter.isEmpty
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                    if (!filter.isEmpty) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        '${_activeFilterCount(filter)} filters active',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: filter.isEmpty
                                    ? Colors.grey.shade400
                                    : colors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      /// Active filter chips — simple
                      if (!filter.isEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 30,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _ActiveFilterChip(
                                label: 'Clear all',
                                icon: Icons.close_rounded,
                                isClear: true,
                                onTap: () => ref
                                    .read(jobsControllerProvider.notifier)
                                    .applyFilter(const JobsFilter()),
                              ),
                              ..._buildFilterChips(filter, ref),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1),

                /// ── Job List ──
                Expanded(
                  child: jobsAsync.when(
                    loading: () => const _SimpleSkeletonLoader(),
                    error: (_, __) => _ErrorView(
                      onRetry: () => ref
                          .read(jobsControllerProvider.notifier)
                          .refresh(),
                    ),
                    data: (page) {
                      if (page.items.isEmpty) {
                        return _EmptyFiltersView(
                          onClear: () => ref
                              .read(jobsControllerProvider.notifier)
                              .applyFilter(const JobsFilter()),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () => ref
                            .read(jobsControllerProvider.notifier)
                            .refresh(),
                        color: colors.primary,
                        backgroundColor: Colors.white,
                        strokeWidth: 3,
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount:
                          page.items.length + (loadingMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index >= page.items.length) {
                              return const _LoadingMoreIndicator();
                            }
                            final job = page.items[index];
                            return JobCard(
                              job: job,
                              onTap: () => context.push('/jobs/${job.id}'),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            /// Scroll to top FAB
            if (_showScrollToTop)
              Positioned(
                right: 16,
                bottom: 100,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: child,
                  ),
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: _scrollToTop,
                    backgroundColor: colors.primary,
                    elevation: 1,
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),

      /// ── Simple Bottom Nav ──
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                Expanded(
                  child: _SimpleNavItem(
                    icon: Icons.work_outline_rounded,
                    activeIcon: Icons.work_rounded,
                    label: 'Jobs',
                    isActive: true,
                    onTap: () {},
                  ),
                ),
                Expanded(
                  child: _SimpleNavItem(
                    icon: Icons.assignment_outlined,
                    activeIcon: Icons.assignment_rounded,
                    label: 'Applications',
                    isActive: false,
                    onTap: () => context.push('/applications'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _activeFilterCount(JobsFilter filter) {
    int count = 0;
    if (filter.searchQuery?.isNotEmpty == true) count++;
    count += filter.locationIds.length;
    count += filter.industryIds.length;
    return count;
  }

  List<Widget> _buildFilterChips(JobsFilter filter, WidgetRef ref) {
    final chips = <Widget>[];
    if (filter.searchQuery?.isNotEmpty == true) {
      chips.add(_ActiveFilterChip(
        label: filter.searchQuery!,
        onTap: () {
          final updated = filter.copyWith(searchQuery: null);
          ref.read(jobsControllerProvider.notifier).applyFilter(updated);
        },
      ));
    }
    return chips;
  }
}

// ═══════════════════════════════════════════
// Components
// ═══════════════════════════════════════════

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.grey.shade700,
              size: 20,
            ),
          ),
          if (badge)
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.label,
    this.icon,
    this.isClear = false,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isClear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isClear
                ? Colors.grey.shade200
                : colors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isClear ? Colors.grey.shade300 : colors.primary.withOpacity(0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isClear ? Colors.grey.shade700 : colors.primary,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 3),
                Icon(
                  icon,
                  size: 12,
                  color: isClear ? Colors.grey.shade700 : colors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleNavItem extends StatelessWidget {
  const _SimpleNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isActive ? colors.primary : Colors.grey.shade500;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isActive ? activeIcon : icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleSkeletonLoader extends StatelessWidget {
  const _SimpleSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 120,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 72,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 72,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingMoreIndicator extends StatelessWidget {
  const _LoadingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading more jobs...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              "Couldn't load jobs",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Something went wrong. Pull down to refresh or try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 14,
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

class _EmptyFiltersView extends StatelessWidget {
  const _EmptyFiltersView({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          const Text(
            'No jobs found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search criteria to find more opportunities.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onClear,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text(
                'Clear Filters',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
