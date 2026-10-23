SCN Jobs — Worker App (Flutter)
Job-portal mobile app for the Indian blue/grey-collar market: build profile
→ browse jobs → apply → track status. Android-first, Play Store target.
Running the app
The app requires an `ENV` flag at run/build time. There is no runtime
environment switch — each build is a distinct artifact.
```bash
# Development (default if omitted)
flutter run --dart-define=ENV=dev

# Staging
flutter run --dart-define=ENV=staging

# Production
flutter run --dart-define=ENV=prod
```
Override the base URL for local backend testing without touching code:
```bash
flutter run --dart-define=ENV=dev --dart-define=BASE_URL=http://10.0.2.2:3000/api
```
Environment flags
Flag	Purpose	Set where
`ENV`	`dev` | `staging` | `prod` — selects base URL	local / CI
`BASE_URL`	Overrides the resolved base URL	local only
`ENV_SENTRY_DSN`	Sentry DSN	CI only, never committed
`ENV_USE_FIREBASE`	Toggles Firebase init per build flavor	CI
Project structure
```
lib/
├── main.dart          — entry point, zone-guarded error capture
├── app.dart           — MaterialApp.router, theme + routing wiring
└── core/
    ├── env/           — AppConfig (single source of env truth)
    ├── theme/         — Material 3 theme + text styles
    ├── router/        — go_router config
    └── utils/         — logger and other cross-cutting helpers
```
Business logic (`domain/`), data (`data/`), and feature screens
(`presentation/features/`) are introduced starting Day 4 as each domain
is built — see `02_Daily_Development_Plan.md` for the full schedule.
Development workflow
`flutter pub get`
`dart analyze` — must be clean before every commit.
`flutter test` — all tests must pass before every commit.
Commit only the files listed for the current day's plan.
Architecture
Clean Architecture (domain / data / presentation), Riverpod for state,
Dio for networking, Isar for local cache, go_router for navigation,
freezed for immutable models. See `01_SCN_JOBS_Flutter_Plan_Corrected.md`
for the full rationale behind each choice.
Testing
```bash
flutter test                 # unit + widget tests
flutter test --coverage      # coverage report (gate: ≥60% on domain/ + data/repositories/)
```
License
Proprietary — SCN Jobs.
<!--
WHY THIS FILE
Onboarding doc for any dev (or AI) picking this repo up cold — how to run
it, what the env flags do, where code lives. Alternative considered:
skipping it until later since Day 1 has almost no code. Rejected — a repo
with zero README from commit 1 trains the team to skip documentation
permanently. Pitfall a junior would hit: hardcoding a dev BASE_URL in
code "temporarily" instead of using the --dart-define override documented
here, then shipping it.