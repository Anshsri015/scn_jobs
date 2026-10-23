import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/network/dio_provider.dart';
import 'package:scn_jobs/data/datasources/auth_remote_datasource.dart'
    show AuthRemoteDataSource, OnboardingStatusUnknownException;
import 'package:scn_jobs/data/repositories/auth_repository_impl.dart';
import 'package:scn_jobs/domain/entities/user.dart';
import 'package:scn_jobs/domain/repositories/auth_repository.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart'
    show profileRepositoryProvider;

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRemoteDataSource(dio);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    secureStorageService: ref.watch(secureStorageServiceProvider),
  );
});

/// Null if no session exists, populated otherwise. Day 5's auth
/// controller invalidates this after a successful login so every
/// screen reading it picks up the new session.
final authStateProvider = FutureProvider<User?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.currentUser();
});

/// Day 14 — whether the logged-in worker still needs profile setup,
/// straight from the backend. This is the raw truth, unaffected by
/// "Skip for now" — Settings and the job-apply gate both need to know
/// the real completion state regardless of whether the router is
/// currently forcing the setup screen or not.
///
/// Primary source is `GET /auth/onboarding-status`'s doc-confirmed
/// `needsOnboarding` flag. If that ever comes back in a shape we
/// can't parse, this does NOT guess/default — it falls back to the
/// worker's own `GET /worker/profile` -> `profileComplete` field, a
/// second, independent signal, so a parsing hiccup on one endpoint
/// can never permanently strand someone on "complete your profile"
/// after they've actually done so.
final onboardingStatusProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return false;
  final repo = ref.watch(authRepositoryProvider);
  try {
    return await repo.needsOnboarding();
  } on OnboardingStatusUnknownException {
    final profileRepo = ref.watch(profileRepositoryProvider);
    final profile = await profileRepo.getProfile();
    return !profile.isComplete;
  }
});

/// Whether the worker has tapped "Skip for now" on `CreateProfileScreen`
/// this session (persisted locally, cleared on logout).
final onboardingSkippedProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageServiceProvider);
  return storage.hasSkippedOnboarding;
});

/// `route_guards.dart`'s ONLY question: should this navigation be
/// bounced to `/profile-setup/create`? True exactly when the backend
/// says onboarding is pending AND the worker hasn't explicitly skipped
/// it. Kept separate from `onboardingStatusProvider` on purpose — a
/// skip changes routing, not the underlying completion state.
final shouldForceOnboardingProvider = FutureProvider<bool>((ref) async {
  final needsOnboarding = await ref.watch(onboardingStatusProvider.future);
  if (!needsOnboarding) return false;
  final skipped = await ref.watch(onboardingSkippedProvider.future);
  return !skipped;
});