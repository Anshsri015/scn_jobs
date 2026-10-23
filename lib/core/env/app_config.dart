/// Application environment, resolved once at compile time from
/// `--dart-define` flags. There is no runtime environment switching —
/// each build (dev/staging/prod) is a distinct artifact.
enum Environment { dev, staging, prod }

/// Single source of truth for environment-dependent configuration.
///
/// Every value here is read from `--dart-define=KEY=VALUE` flags passed
/// to `flutter run` / `flutter build`. No screen or service should read
/// `String.fromEnvironment` directly — always go through [AppConfig].
class AppConfig {
  AppConfig._();

  static const String _envRaw = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  /// The resolved [Environment] for this build.
  static final Environment environment = _parseEnvironment(_envRaw);

  static Environment _parseEnvironment(String raw) {
    switch (raw) {
      case 'staging':
        return Environment.staging;
      case 'prod':
        return Environment.prod;
      case 'dev':
      default:
        return Environment.dev;
    }
  }

  /// Base URL for all API calls. Overridable via `--dart-define=BASE_URL=...`
  /// for local backend testing; otherwise resolved from [environment].
  static String get baseUrl {
    const override = String.fromEnvironment('BASE_URL');
    if (override.isNotEmpty) return override;

    switch (environment) {
      case Environment.dev:
      // Updated Sep 2026 — moved off the Render free-tier backend
      // (portal-z00v.onrender.com) to the same Vercel deployment prod
      // uses. Render's cold start was exceeding Dio's 25s receiveTimeout
      // and aborting requests on first launch after idle.
        return 'https://portal-orcin-eta.vercel.app/api';
      case Environment.staging:
        return 'https://portal-orcin-eta.vercel.app/api';
      case Environment.prod:
      // Updated Sep 2026 — moved off the old api.scnjobs.in domain to
      // this Vercel deployment specifically to fix C2 (Render free-tier
      // cold starts exceeding Dio's 15s timeout and failing the Play
      // Store reviewer's first launch). Vercel serverless functions can
      // still cold-start on a truly idle route, but nowhere near the
      // multi-second Render free-tier delay this was replacing.
        return 'https://portal-orcin-eta.vercel.app/api';
    }
  }

  /// Sentry DSN — set only in CI, never committed to the repo.
  static const String sentryDsn = String.fromEnvironment('ENV_SENTRY_DSN');

  /// Whether this build flavor should initialize Firebase.
  static const bool useFirebase = bool.fromEnvironment(
    'ENV_USE_FIREBASE',
    defaultValue: true,
  );

  /// True only for release builds — used to hide dev-only affordances
  /// like the "Use dev OTP" shortcut button.
  static const bool isRelease = bool.fromEnvironment('dart.vm.product');

  /// Human-readable label, useful in the About screen and debug logs.
  static String get label => environment.name.toUpperCase();
}

// WHY THIS FILE
// Every environment-dependent value (base URL, feature flags, Sentry DSN)
// flows through this one class so switching ENV=dev to ENV=prod never
// touches business logic or screen code — just the build command.
// Alternative considered: a `.env` file read at runtime via `flutter_dotenv`.
// Rejected because `--dart-define` is compile-time, tamper-proof in release
// builds, and needs no asset bundling or runtime file I/O.
// Pitfall a junior would hit: hardcoding a base URL in a datasource file
// "just for testing" and forgetting to revert it before merging to main.