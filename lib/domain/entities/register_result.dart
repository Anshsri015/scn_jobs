/// Result of a successful worker registration request.
///
/// [devOtp] is only ever non-null in non-production backend environments
/// (API docs §1.4 — real SMS is currently disabled, so the backend
/// echoes the OTP it generated so testers can complete the flow without
/// waiting on SMS delivery). This is carried all the way from the
/// datasource up through the repository/use-case/controller — nothing
/// in that chain hides it — but `DevOtpCache` (which the controller
/// writes it into) refuses to store or return it in release builds, so
/// a shipped app can never end up displaying it.
class RegisterResult {
  const RegisterResult({required this.userId, this.devOtp});

  final String userId;
  final String? devOtp;
}

// WHY THIS FILE
// registerWorker used to return a bare `Future<String>` (just userId),
// with an explicit repo-contract comment saying devOtp was deliberately
// dropped as "debug convenience, not something the repo contract should
// expose." That was correct in spirit but left no way to test the OTP
// flow at all while backend SMS is disabled — the app was untestable
// end-to-end. This entity is the minimal change that un-blocks testing:
// devOtp rides along as an explicit, nullable field, and every layer
// that doesn't care about it just ignores it.
// Alternative considered: a Dio interceptor that intercepts responses
// and squirrels devOtp away into a side-channel singleton, keeping the
// repository contract untouched. Rejected — that's "clean" on paper but
// actually harder to trace (a screen reading dev-only state that
// bypasses every layer we just built) and no easier to keep out of
// release builds than this explicit field is.
// Pitfall a junior would hit: reading `devOtp` directly in a screen
// instead of going through `DevOtpCache.read()` — the cache is what
// enforces "never in release mode," a screen reading the field straight
// off a stored `RegisterResult` has no such guardrail.
