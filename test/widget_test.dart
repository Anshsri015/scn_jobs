import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scn_jobs/app.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';

void main() {
  testWidgets(
    'ScnJobsApp boots and lands on Login when no session exists',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // No real Dio/secure-storage hit in a widget test — the
            // splash screen just needs a resolved "no session" result
            // so it redirects to /login deterministically.
            authStateProvider.overrideWith((ref) async => null),
          ],
          child: const ScnJobsApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Log in'), findsWidgets);
    },
  );

  testWidgets('MaterialApp uses Material 3', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) async => null),
        ],
        child: const ScnJobsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
  });
}

// WHY THIS FILE
// The one smoke test required to pass before any Day 1 commit — proves
// the app boots, the router renders a screen, and the theme is wired.
//
// Day 5 update: the app no longer lands directly on a placeholder Home
// route — it starts at /splash and redirects based on session state
// (authStateProvider). Wrapping in ProviderScope with authStateProvider
// overridden to `null` keeps this test fast and deterministic (no real
// network/secure-storage call) and asserts against the Login screen,
// which is now the correct "no session" outcome instead of Day 1's
// bootstrap placeholder text.
// Pitfall a junior would hit: asserting on exact widget instances instead
// of `find.text`/`find.byType`, making the test brittle to harmless
// refactors later. Also: forgetting to override authStateProvider here
// would make this test flaky/slow since it'd hit real secure storage.
