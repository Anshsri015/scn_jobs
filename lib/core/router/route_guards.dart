import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/data/repositories/auth_repository_impl.dart'
    show SessionCheckException;
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';

class RouteGuards {
  RouteGuards(this.ref);
  final Ref ref;

  static const _publicRoutes = {
    '/splash',
    '/onboarding',
    '/login',
    '/register',
    '/verify-otp',
    '/forgot-password',
    '/reset-password',
  };

  static const _onboardingEntryRoute = '/profile-setup/create';

  String? authGuard(BuildContext context, GoRouterState state) {
    final userState = ref.read(authStateProvider); // AsyncValue<User?>

    if (userState.isLoading) return null; // splash decide karega

    // WHY: splash navigates straight to /home on a saved session
    // without waiting for `/auth/me` to confirm it (see SplashScreen's
    // optimistic-navigation comment). If that background confirmation
    // then fails with a `SessionCheckException` (network hiccup, not
    // a real 401), this guard must NOT treat it as "logged out" —
    // otherwise it would yank the user straight back to /login while
    // the splash's own auto-retry is still quietly working in the
    // background. A genuine 401 still resolves to `null` data (not an
    // error), so that path is unaffected and still logs the user out.
    if (userState.hasError && userState.error is SessionCheckException) {
      return null;
    }

    final loggedIn = userState.asData?.value != null;
    final onPublicRoute = _publicRoutes.contains(state.matchedLocation);

    if (!loggedIn && !onPublicRoute) return '/login';
    if (loggedIn && onPublicRoute && state.matchedLocation != '/splash') {
      return '/home';
    }

    // Day 14 — logged in worker, not on a public route: check whether
    // profile setup is still pending. Already-on-profile-setup and
    // /settings/* routes are exempt so the flow itself, plus editing
    // an already-complete profile, are never redirect-looped.
    //
    // ⚠️ This used to also blanket-exempt /home, /jobs, /applications
    // ("browsing routes") so a "Skip for now" button could work — but
    // that exempted EVERY entry to those routes, including a brand
    // new worker's very first landing right after registering, who
    // never chose to skip anything. `shouldForceOnboardingProvider`
    // (auth_providers.dart) is the real fix: it only allows through
    // when the worker actually tapped Skip (persisted flag), not for
    // every logged-in visit to those routes.
    if (loggedIn) {
      final onProfileSetupRoute =
      state.matchedLocation.startsWith('/profile-setup');
      final onSettingsRoute = state.matchedLocation.startsWith('/settings');

      if (!onProfileSetupRoute && !onSettingsRoute) {
        final forceState = ref.read(shouldForceOnboardingProvider);
        // Still loading or errored: don't block navigation on it — the
        // refresh notifier re-evaluates once it resolves. Treating an
        // in-flight check as "no redirect needed" avoids stranding the
        // user on a blank screen while this one extra call is pending.
        final mustOnboard = forceState.asData?.value ?? false;
        if (mustOnboard) return _onboardingEntryRoute;
      }
    }

    return null;
  }
}
