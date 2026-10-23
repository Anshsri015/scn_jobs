import 'package:flutter/foundation.dart';

/// In-memory cache of dev-only OTPs, keyed by phone number.
///
/// The backend's real SMS sending is currently disabled (API docs §1.4)
/// — register/resend-otp responses carry a `devOtp` field in non-prod
/// environments so testers can complete the OTP flow without waiting on
/// SMS delivery. `AuthController` writes into this cache after a
/// successful register/resend; `VerifyOtpScreen` reads from it (keyed
/// by the phone it already has) to show a debug-only "Dev OTP: 123456"
/// chip with a one-tap autofill.
///
/// Intentionally in-memory only — not persisted to Isar/secure storage.
/// A leftover dev OTP surviving an app restart is exactly the kind of
/// stale-state bug that's confusing to debug later; losing it on
/// restart is the correct behavior, not a limitation.
class DevOtpCache {
  DevOtpCache._();

  static final Map<String, String> _cache = {};

  /// No-op in release builds and for a null [otp] — the whole point of
  /// this cache is that it can never hold anything a shipped app could
  /// accidentally display, so release-mode is enforced at the write
  /// site, not just the read site.
  static void store(String phone, String? otp) {
    if (kReleaseMode || otp == null) return;
    _cache[phone] = otp;
  }

  static String? read(String phone) => kReleaseMode ? null : _cache[phone];
}

// WHY THIS FILE
// A single dev-only cache means `VerifyOtpScreen` needs zero new
// constructor parameters and `app_router.dart` needs zero changes to
// pass devOtp through route `extra` — the screen already has `phone`,
// which is the only key this cache needs.
// Alternative considered: passing `devOtp` through `context.push('/verify-otp', extra: ...)`
// as part of a small args object. Rejected — that touches the route
// definition in `app_router.dart` for a debug-only convenience feature,
// and every future navigation to this screen (e.g. "resend from a
// notification deep link", if that's ever added) would need to
// remember to thread devOtp through too. A cache keyed by phone doesn't
// care how the screen was reached.
// Pitfall a junior would hit: checking `kReleaseMode` only in the
// screen's UI code and not in this cache — that would mean a release
// build still *stores* real OTPs in memory (harmless on its own, but a
// future refactor that adds a debug menu or log dump could then leak
// them). Enforcing it at `store()` closes that off entirely.
