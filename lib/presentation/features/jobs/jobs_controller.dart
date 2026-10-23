import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/network/pagination.dart';
import 'package:scn_jobs/domain/entities/job.dart';
import 'package:scn_jobs/domain/usecases/fetch_jobs_usecase.dart';
import 'package:scn_jobs/presentation/providers/jobs/job_providers.dart';

/// Presentation-only filter shape — kept out of `domain/` deliberately.
/// `FetchJobsUseCase` takes the same fields as loose named parameters
/// instead of this class, so the domain layer has no idea a "filter
/// object" concept exists in the UI.
class JobsFilter {
  const JobsFilter({
    this.searchQuery,
    this.locationIds = const [],
    this.industryIds = const [],
  });

  final String? searchQuery;
  final List<String> locationIds;
  final List<String> industryIds;

  bool get isEmpty =>
      (searchQuery == null || searchQuery!.isEmpty) &&
      locationIds.isEmpty &&
      industryIds.isEmpty;

  JobsFilter copyWith({
    String? searchQuery,
    List<String>? locationIds,
    List<String>? industryIds,
  }) {
    return JobsFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      locationIds: locationIds ?? this.locationIds,
      industryIds: industryIds ?? this.industryIds,
    );
  }
}

class JobsController extends AsyncNotifier<Page<Job>> {
  late final FetchJobsUseCase _fetchJobsUseCase;
  JobsFilter _filter = const JobsFilter();

  JobsFilter get filter => _filter;

  @override
  Future<Page<Job>> build() async {
    _fetchJobsUseCase = FetchJobsUseCase(ref.read(jobRepositoryProvider));
    return _fetchJobsUseCase(
      searchQuery: _filter.searchQuery,
      locationIds: _filter.locationIds.isEmpty ? null : _filter.locationIds,
      industryIds: _filter.industryIds.isEmpty ? null : _filter.industryIds,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchJobsUseCase(
        searchQuery: _filter.searchQuery,
        locationIds: _filter.locationIds.isEmpty ? null : _filter.locationIds,
        industryIds: _filter.industryIds.isEmpty ? null : _filter.industryIds,
      ),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    final loadingMoreNotifier = ref.read(jobsLoadingMoreProvider.notifier);
    if (current == null ||
        !current.hasMore ||
        ref.read(jobsLoadingMoreProvider)) {
      return;
    }

    loadingMoreNotifier.state = true;
    try {
      final next = await _fetchJobsUseCase(
        cursor: current.cursor,
        searchQuery: _filter.searchQuery,
        locationIds: _filter.locationIds.isEmpty ? null : _filter.locationIds,
        industryIds: _filter.industryIds.isEmpty ? null : _filter.industryIds,
      );
      state = AsyncValue.data(
        current.appending(
          next.items,
          newHasMore: next.hasMore,
          newCursor: next.cursor,
        ),
      );
    } finally {
      loadingMoreNotifier.state = false;
    }
  }

  Future<void> applyFilter(JobsFilter filter) async {
    _filter = filter;
    await refresh();
  }
}

final jobsControllerProvider =
    AsyncNotifierProvider<JobsController, Page<Job>>(JobsController.new);

/// Separate from `jobsControllerProvider.state` on purpose — see this
/// file's WHY block for why load-more can't just be
/// `AsyncValue.loading()`.
final jobsLoadingMoreProvider = StateProvider<bool>((ref) => false);

// WHY THIS FILE
// `loadMore()` deliberately does NOT set `state = AsyncValue.loading()`
// — doing so would replace the already-visible job list with a
// full-screen spinner every time the user scrolls near the bottom,
// which is jarring. Instead `jobsLoadingMoreProvider` (a separate plain
// `StateProvider<bool>`) tracks it, so `HomeScreen` can show a small
// inline footer spinner without losing the scroll position or the
// already-loaded items.
// Pitfall a junior would hit: calling `loadMore()` without the
// `current.hasMore` / `jobsLoadingMoreProvider` guard — a fast scroll
// can fire multiple `loadMore()` calls before the first one resolves,
// each appending a duplicate page.
