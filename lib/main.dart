import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';

import 'package:scn_jobs/app.dart';
import 'package:scn_jobs/core/env/app_config.dart';
import 'package:scn_jobs/core/network/dio_provider.dart';
import 'package:scn_jobs/core/router/app_router.dart';
import 'package:scn_jobs/core/storage/isar_service.dart';
import 'package:scn_jobs/core/utils/logger.dart';
import 'package:scn_jobs/data/local/notification_local_model.dart';
import 'package:scn_jobs/presentation/providers/notifications/notifications_providers.dart';

// ⚠️ REQUIRES MANUAL SETUP — this import will not resolve until you
// run `flutterfire configure` against a real Firebase project. See the
// Day 18 setup instructions. This file cannot compile without it.

void main() {
  runZonedGuarded<void>(
        () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.e(
          'FlutterError: ${details.exceptionAsString()}',
          details.exception,
          details.stack,
        );
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.e('PlatformDispatcher error', error, stack);
        return true;
      };

      AppLogger.i('Booting SCN Jobs — env: ${AppConfig.label}');
      AppLogger.i('Base URL: ${AppConfig.baseUrl}');

      // First real Isar schema (Day 18) — deferred since Day 1 for
      // exactly this moment. See isar_service.dart's WHY block.
      await IsarService.instance.init(schemas: [NotificationLocalModelSchema]);

      // A ProviderContainer built before `runApp` lets us call
      // `notificationService.initialize(...)` — which needs the router
      // to navigate on a notification tap — before the widget tree
      // (and therefore `ref.watch(routerProvider)`) exists.
      // `UncontrolledProviderScope` hands this same container to the
      // widget tree afterward, so it's the same container throughout,
      // not a second one.
      final container = ProviderContainer();

      // Unconditional Render free-tier warm-up — fire-and-forget, not
      // awaited, so it never delays first paint. `SplashScreen`'s own
      // `/auth/me` call already wakes the backend, but ONLY when a
      // saved session exists (`AuthRepositoryImpl.currentUser` returns
      // early otherwise) — so a brand-new worker going straight into
      // register → create-profile → personal-details has zero warm-up
      // calls before hitting the API for real. That gap is what let
      // `POST /worker/profile` / `PATCH /worker/profile` land on a
      // still-sleeping instance and appear to silently fail on a
      // worker's very first attempt, then succeed the moment they
      // retried. Any response (even an error/404) means the instance
      // has been touched and is spinning up, so failures here are
      // intentionally ignored.
      // WHY `.catchError((_) {})` WAS REMOVED: `dioProvider.get<void>(...)`
      // returns a `Future<Response<void>>`. `catchError`'s handler must
      // return a value of that SAME type — `(_) {}` returns `null`
      // (void), not a `Response<void>`, so Dart throws
      // "Invalid argument(s) (onError): The error handler of
      // Future.catchError must return a value of the future's type" as
      // an uncaught zone error on every single app start (visible in
      // logs right after the intentional 404 from this same warm-up
      // call). A try/catch around an async closure sidesteps the
      // return-type requirement entirely.
      unawaited(
            () async {
          try {
            await container.read(dioProvider).get<void>(
              '/',
              options: Options(
                sendTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 30),
                connectTimeout: const Duration(seconds: 30),
                // 'noRetry': this is a fire-and-forget wake-up ping,
                // not a real request — no point stacking retries.
                // 'silentLog': a 404 here is the EXPECTED, successful
                // outcome (see the big comment above), not a failure
                // worth flagging in the console.
                extra: {'noRetry': true, 'silentLog': true},
              ),
            );
          } catch (_) {
            // Any response (even an error/404) means the instance has
            // been touched and is spinning up — failures here are
            // intentionally ignored.
          }
        }(),
      );

      final router = container.read(routerProvider);
      await container.read(notificationServiceProvider).initialize(
        onNotificationTap: router.go,
      );

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const ScnJobsApp(),
        ),
      );
    },
        (error, stack) {
      AppLogger.e('Uncaught zone error', error, stack);
    },
  );
}

// WHY THIS FILE
// Every uncaught error — sync (FlutterError), async platform-level
// (PlatformDispatcher), and anything escaping the zone — is captured
// here in one place before Crashlytics/Sentry are wired (still
// pending), so no crash-reporting integration ever needs a second
// entry point.
// Day 18 addition: Firebase must initialize BEFORE anything touches
// FirebaseMessaging/notifications — hence its position right after the
// error-handler setup and before Isar/notification-service init.
// Pitfall a junior would hit: building `ScnJobsApp()` with a fresh,
// default `ProviderScope()` instead of `UncontrolledProviderScope`
// wrapping the `container` already used above — that would silently
// create a SECOND container, meaning `notificationServiceProvider`'s
// `initialize()` call (which ran against the first container) has no
// effect on the actual running app.
