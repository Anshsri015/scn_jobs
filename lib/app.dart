import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/router/app_router.dart';
import 'package:scn_jobs/core/theme/app_theme.dart';
import 'package:scn_jobs/presentation/features/shared/maintenance_screen.dart';
import 'package:scn_jobs/presentation/providers/health/health_providers.dart';
import 'package:scn_jobs/presentation/providers/notifications/notification_sync_controller.dart';

/// Root widget. Wires theme + router, and gates the whole router behind
/// `backendHealthyProvider` (Day 19) — a down backend means every
/// screen would fail anyway, so `MaintenanceScreen` replaces the router
/// entirely rather than each screen handling "backend is down" separately.
class ScnJobsApp extends ConsumerWidget {
  const ScnJobsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnhealthy = ref.watch(backendHealthyProvider);
    // Keeps the notifications SSE stream + history sync alive for the
    // whole logged-in session (opens on login, closes on logout /
    // app-background). Watching it here is what starts it.
    ref.watch(notificationSyncControllerProvider);

    return MaterialApp.router(
      title: 'SCN Jobs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      // Router root par hi rehta hai (back-button dispatcher, dialogs,
      // GoRouter stack sab intact) — `builder` sirf render ko replace
      // karta hai jab backend down ho, `home:` swap karne ki tarah
      // Navigator hierarchy ko toड़ta nahi.
      builder: (context, child) =>
      isUnhealthy ? const MaintenanceScreen() : child!,
    );
  }
}

// WHY THIS FILE
// Uses `MaterialApp.router(routerConfig: ...)` with the maintenance gate
// applied via `builder:`, not by swapping `home:` for
// `Router.withConfig(...)`. That `home:`-swap pattern was tried earlier
// and reverted: it wraps GoRouter's Navigator inside a second, implicit
// outer Navigator that MaterialApp creates for `home`, which detaches
// the system back-button dispatcher from GoRouter. Symptom: pressing
// back while a dialog (e.g. withdraw-application confirm) is open
// doesn't dismiss the dialog — it pops a page instead — and once
// GoRouter's stack and the OS back stack disagree, back eventually
// exits the app instead of navigating up.
// `builder:` keeps the Router as the single root Navigator (dialogs,
// back button, and GoRouter's stack all stay wired correctly) and just
// replaces the rendered child with `MaintenanceScreen` when unhealthy.
// Pitfall a junior would hit: gating individual screens' `build()`
// methods with their own `if (isUnhealthy)` checks instead of this one
// central gate — that's N places to keep in sync instead of one, and
// a screen already mid-navigation when the backend drops would still
// render its own broken UI instead of falling back cleanly.
