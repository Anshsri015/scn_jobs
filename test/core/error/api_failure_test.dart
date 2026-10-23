import 'package:flutter_test/flutter_test.dart';

import 'package:scn_jobs/core/error/api_failure.dart';

/// Mirrors the pattern every screen will use to turn an [ApiFailure] into
/// a display string (e.g. inside a SnackBar). Exists here purely to prove
/// the `switch` is exhaustive — if a new subtype is added to
/// `api_failure.dart` without a corresponding case here, this file fails
/// to *compile*, not just fails a test.
String describe(ApiFailure failure) {
  return switch (failure) {
    NetworkFailure() => 'network: ${failure.message}',
    ServerFailure(:final statusCode) =>
      'server[$statusCode]: ${failure.message}',
    UnauthorizedFailure() => 'unauthorized: ${failure.message}',
    ValidationFailure(:final fieldErrors) =>
      'validation(${fieldErrors?.length ?? 0} fields): ${failure.message}',
    CacheFailure() => 'cache: ${failure.message}',
    UnknownFailure() => 'unknown: ${failure.message}',
  };
}

void main() {
  group('ApiFailure', () {
    test('NetworkFailure carries its default message', () {
      const failure = NetworkFailure();
      expect(describe(failure), contains('network:'));
      expect(failure.message, isNotEmpty);
    });

    test('ServerFailure carries a status code', () {
      const failure = ServerFailure('Internal error', statusCode: 500);
      expect(describe(failure), 'server[500]: Internal error');
    });

    test('UnauthorizedFailure carries its default message', () {
      const failure = UnauthorizedFailure();
      expect(describe(failure), contains('unauthorized:'));
    });

    test('ValidationFailure carries field-level errors', () {
      const failure = ValidationFailure(
        'Fix the highlighted fields',
        fieldErrors: {'phone': 'Invalid format'},
      );
      expect(
        describe(failure),
        'validation(1 fields): Fix the highlighted fields',
      );
    });

    test('CacheFailure carries its default message', () {
      const failure = CacheFailure();
      expect(describe(failure), contains('cache:'));
    });

    test('UnknownFailure carries its default message', () {
      const failure = UnknownFailure();
      expect(describe(failure), contains('unknown:'));
    });
  });
}

// WHY THIS FILE
// The real value of this test isn't the assertions — it's that `describe()`
// only compiles if its `switch` covers every subtype of the sealed
// `ApiFailure`. The moment someone adds a 7th failure type in
// `api_failure.dart` without updating a switch like this one anywhere in
// the app, that switch (here or in real UI code) fails to compile,
// catching the gap at build time instead of a missed error state in prod.
// Alternative considered: a single test asserting `ApiFailure` subtypes
// exist via `is` checks. Rejected — `is` checks compile regardless of
// whether a switch is exhaustive, so they can't catch a forgotten case.
// Pitfall a junior would hit: adding `default => 'unknown'` to silence a
// compiler error when a new failure type breaks this switch — that
// defeats the entire mechanism this test exists to protect.
