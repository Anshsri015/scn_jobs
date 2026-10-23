import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scn_jobs/core/network/dio_provider.dart';
import 'package:scn_jobs/core/router/route_guards.dart';
import 'package:scn_jobs/core/storage/isar_service.dart';
import 'package:scn_jobs/domain/entities/application.dart';
import 'package:scn_jobs/domain/entities/job.dart';
import 'package:scn_jobs/presentation/features/account/about_screen.dart';
import 'package:scn_jobs/presentation/features/account/edit_profile_screen.dart';
import 'package:scn_jobs/presentation/features/account/notifications_screen.dart';
import 'package:scn_jobs/presentation/features/account/settings_screen.dart';
import 'package:scn_jobs/presentation/features/applications/application_detail_loader.dart';
import 'package:scn_jobs/presentation/features/applications/application_detail_screen.dart';
import 'package:scn_jobs/presentation/features/applications/my_applications_screen.dart';
import 'package:scn_jobs/presentation/features/auth/forgot_password_screen.dart';
import 'package:scn_jobs/presentation/features/auth/login_screen.dart';
import 'package:scn_jobs/presentation/features/auth/register_screen.dart';
import 'package:scn_jobs/presentation/features/auth/reset_password_screen.dart';
import 'package:scn_jobs/presentation/features/auth/verify_otp_screen.dart';
import 'package:scn_jobs/presentation/features/jobs/apply_screen.dart';
import 'package:scn_jobs/presentation/features/jobs/home_screen.dart';
import 'package:scn_jobs/presentation/features/jobs/job_detail_screen.dart';
import 'package:scn_jobs/presentation/features/jobs/search_filter_screen.dart';
import 'package:scn_jobs/presentation/features/onboarding/onboarding_screen.dart';
import 'package:scn_jobs/presentation/features/profile_setup/profile_setup_router.dart';
import 'package:scn_jobs/presentation/features/splash/splash_screen.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart'
    show currentProfileProvider;

/// App-wide router configuration.
///
/// Day 1 shipped a single placeholder route. Day 5 wired the real entry
/// point + auth-gated redirect. Day 6 adds onboarding/register/verify.
/// Day 7 adds forgot/reset password + settings. Day 9 splices in the
/// profile-setup route list. Day 14 adds settings/edit-profile. Day
/// 16-17 replace the `/home` placeholder with the real job feed and add
/// Jobs/Applications routes. Days 18+ only ever add a `GoRoute` here
/// (or to a feature's own route-list file) — no second navigation
/// pattern gets introduced mid-project.
class AppRouter {
  AppRouter._();

  static GoRouter build(Ref ref) {
    final routeGuards = RouteGuards(ref);

    return GoRouter(
      initialLocation: '/splash',
      debugLogDiagnostics: true,
      refreshListenable: _GoRouterRefreshNotifier(ref),
      redirect: routeGuards.authGuard,
      routes: [
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/verify-otp',
          name: 'verify-otp',
          // RegisterScreen `context.push('/verify-otp?phone=...&email=...')`
          // se navigate karta hai. `email` sirf display ke liye hai
          // (VerifyOtpScreen mein), API calls ab bhi `phone` hi use
          // karte hain — backend contract wahi hai.
          //
          // Query params, `extra` ki tarah nahi — URL ka hi part hain,
          // isliye kisi bhi route rebuild (refreshListenable se, ya app
          // background se kill hoke restore hone se) ke baad bhi zinda
          // rehte hain. Pehle `extra` use hota tha: `state.extra` force
          // -unwrap crash deta tha jab null hota (background-restore
          // case), aur baad me null-safe fallback (`extra is! (...) ->
          // RegisterScreen`) khud ek naya bug ban gaya — OTP verify
          // hone ke turant baad `authStateProvider` invalidate hote hi
          // `_GoRouterRefreshNotifier` is route ko rebuild karwata tha
          // (user abhi bhi `/verify-otp` par hi tha, apne khud ke 1.5s
          // delay ke beech), aur us rebuild mein `extra` gayab ho jata
          // tha — fallback fir se `RegisterScreen` dikha deta, jab
          // tak screen ka apna `context.go('/home')` na chal jaye. Query
          // params us poori class of bug ko hata dete hain.
          builder: (context, state) {
            final phone = state.uri.queryParameters['phone'];
            final email = state.uri.queryParameters['email'];
            if (phone == null || phone.isEmpty) {
              return const RegisterScreen();
            }
            return VerifyOtpScreen(phone: phone, email: email ?? '');
          },
        ),
        GoRoute(
          path: '/forgot-password',
          name: 'forgotPassword',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/reset-password',
          name: 'resetPassword',
          // ForgotPasswordScreen navigates here via
          // `context.push('/reset-password?email=...')` right after
          // the OTP is sent. Same query-param (not `extra`) approach
          // as `/verify-otp` above, for the same reason — survives a
          // route rebuild mid-flow instead of an `extra` null crash.
          // `email` is optional here too: a worker can also reach this
          // screen directly ("I already have a code") without having
          // just come from the send-OTP screen, and types it in
          // manually on the screen itself in that case.
          builder: (context, state) {
            final email = state.uri.queryParameters['email'];
            return ResetPasswordScreen(initialEmail: email);
          },
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/settings/edit-profile',
          name: 'editProfile',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/settings/about',
          name: 'about',
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/jobs/filter',
          name: 'jobsFilter',
          builder: (context, state) => const SearchFilterScreen(),
        ),
        GoRoute(
          path: '/jobs/:id',
          name: 'jobDetail',
          builder: (context, state) =>
              JobDetailScreen(jobId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/jobs/:id/apply',
          name: 'applyToJob',
          // JobDetailScreen `context.push('/jobs/$id/apply', extra: job)`
          // se navigate karta hai — extra (the fetched Job) ke bina crash.
          builder: (context, state) => ApplyScreen(job: state.extra! as Job),
        ),
        GoRoute(
          path: '/applications',
          name: 'myApplications',
          builder: (context, state) => const MyApplicationsScreen(),
        ),
        GoRoute(
          path: '/applications/:id',
          name: 'applicationDetail',
          // MyApplicationsScreen supplies `extra: app` — renders
          // directly, no fetch. A notification deep link (Day 18) has
          // no `extra` — falls back to fetch-by-id via
          // ApplicationDetailLoader. See app_router.dart's WHY block.
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Application) {
              return ApplicationDetailScreen(application: extra);
            }
            return ApplicationDetailLoader(
              applicationId: state.pathParameters['id']!,
            );
          },
        ),
        ...profileSetupRoutes,
      ],
    );
  }
}

class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    // Auto-logout: a logged-in request got a 401 (expired token or
    // deleted account). Clear the session; authStateProvider then
    // resolves to null and the route guard sends the user to /login.
    var handling = false;
    Future<void> onSessionExpired() async {
      if (handling) return;
      handling = true;
      try {
        final storage = ref.read(secureStorageServiceProvider);
        if (!await storage.hasSession) return;
        await storage.clearSession();
        try {
          await IsarService.instance.clearAllData();
        } catch (_) {}
        ref.invalidate(authStateProvider);
        ref.invalidate(currentProfileProvider);
      } finally {
        handling = false;
      }
    }

    sessionExpiredNotifier.addListener(onSessionExpired);
    ref.onDispose(() => sessionExpiredNotifier.removeListener(onSessionExpired));
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    // Day 14 — shouldForceOnboardingProvider resolves asynchronously
    // after authStateProvider does (and again whenever the "skip" flag
    // changes); without this the redirect only re-runs on the next
    // manual navigation instead of as soon as either check comes back.
    ref.listen(shouldForceOnboardingProvider, (_, __) => notifyListeners());
  }
}

/// Exposes the router so `app.dart` can do
/// `MaterialApp.router(routerConfig: ref.watch(routerProvider), ...)`.
final routerProvider = Provider<GoRouter>(AppRouter.build);

// WHY THIS FILE
// `/jobs/:id` and `/jobs/:id/apply` use `extra` to pass an
// already-fetched `Job` forward instead of re-fetching by id — see
// `job_detail_screen.dart` and `apply_screen.dart`'s own WHY notes.
// These two are NOT deep-linkable from outside the app (e.g. a push
// notification) as written — only reachable via in-app navigation that
// supplies `extra`. `/applications/:id` WAS the same until Day 18 added
// `ApplicationDetailLoader` as an extra-null fallback (see the
// path-builder above) specifically because push notifications need to
// deep-link straight to an application's status. If jobs ever need the
// same (e.g. a "new job posted" push), that route needs the same
// loader pattern, not a redesign of this file.
// Pitfall a junior would hit: forgetting `...profileSetupRoutes` stays
// last in the list — go_router matches routes in order, and
// `/profile-setup/create` etc. don't collide with anything above, but
// keeping feature route-lists spread in at the end (not interleaved)
// keeps this file's own routes easy to scan.
