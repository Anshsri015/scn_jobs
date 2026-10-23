import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:scn_jobs/core/error/exceptions.dart';
import 'package:scn_jobs/core/utils/logger.dart';

/// Wraps [FlutterSecureStorage] for everything auth-related.
///
/// Backed by Android Keystore / iOS Keychain — never SharedPreferences.
/// This is the *only* place in the app that should import
/// `flutter_secure_storage` directly; every other layer goes through
/// this service so the storage backend can be swapped later without
/// touching auth/repository code.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
      const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'scn_access_token';
  static const String _refreshTokenKey = 'scn_refresh_token';
  static const String _onboardingSkippedKey = 'scn_onboarding_skipped';
  static const String _displayNameKey = 'scn_display_name';

  Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _accessTokenKey, value: token);
    } catch (e, st) {
      AppLogger.e('Failed to save access token', e, st);
      throw const CacheException('Could not save session. Please try again.');
    }
  }

  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (e, st) {
      AppLogger.e('Failed to read access token', e, st);
      throw const CacheException('Could not read session.');
    }
  }

  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
    } catch (e, st) {
      AppLogger.e('Failed to save refresh token', e, st);
      throw const CacheException('Could not save session. Please try again.');
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e, st) {
      AppLogger.e('Failed to read refresh token', e, st);
      throw const CacheException('Could not read session.');
    }
  }

  /// Clears both tokens — called on logout and on a 401 that survives
  /// the refresh-token attempt (wired in `auth_interceptor.dart`, Day 3).
  /// Also clears the onboarding-skipped flag (below) — a fresh login
  /// (same or different account) should never inherit a previous
  /// session's "skip" choice.
  Future<void> clearSession() async {
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _onboardingSkippedKey);
      await _storage.delete(key: _displayNameKey);
    } catch (e, st) {
      AppLogger.e('Failed to clear session', e, st);
      throw const CacheException('Could not clear session.');
    }
  }

  Future<bool> get hasSession async => (await getAccessToken()) != null;

  /// WHY THIS EXISTS: the backend only ever returns the worker's name
  /// once — in `POST /auth/worker/verify-otp`'s response (`name` /
  /// `firstName` / `lastName`). `GET /auth/me` (used everywhere else,
  /// including every app-restart session check) does NOT include it —
  /// see the doc-confirmed response shape (`id`, `email`, `phone`,
  /// `role`, `isActive` only). So there is no backend endpoint the app
  /// can re-fetch this from later; it has to be captured once, right
  /// after registration/verification, and kept locally so screens like
  /// `PersonalDetailsScreen` can prefill it without asking the worker
  /// to retype something they already gave.
  Future<void> saveDisplayName(String name) async {
    try {
      await _storage.write(key: _displayNameKey, value: name);
    } catch (e, st) {
      // Non-fatal — losing this only means a prefill field starts
      // blank instead of blocking login/registration entirely.
      AppLogger.e('Failed to save display name', e, st);
    }
  }

  Future<String?> getDisplayName() async {
    try {
      return await _storage.read(key: _displayNameKey);
    } catch (e, st) {
      AppLogger.e('Failed to read display name', e, st);
      return null;
    }
  }

  /// Set when the worker explicitly taps "Skip for now" on
  /// `CreateProfileScreen`. `route_guards.dart` checks this (via
  /// `shouldForceOnboardingProvider`) so a skip is remembered across
  /// app restarts and doesn't re-prompt on every launch — but it never
  /// overrides the backend's own onboarding-status truth outside of
  /// that one redirect decision, so Settings can still show "Complete
  /// your profile" and job-apply can still block on it.
  Future<void> markOnboardingSkipped() async {
    try {
      await _storage.write(key: _onboardingSkippedKey, value: 'true');
    } catch (e, st) {
      AppLogger.e('Failed to save onboarding-skipped flag', e, st);
    }
  }

  Future<bool> get hasSkippedOnboarding async {
    try {
      return (await _storage.read(key: _onboardingSkippedKey)) == 'true';
    } catch (e, st) {
      AppLogger.e('Failed to read onboarding-skipped flag', e, st);
      return false;
    }
  }
}

// WHY THIS FILE
// Centralizing token read/write behind one service means the auth
// interceptor (Day 3), login flow (Day 5), and logout action all agree
// on exactly two keys and one clearing method — no risk of one screen
// using a different SharedPreferences-style key string than another.
// Alternative considered: reading/writing FlutterSecureStorage directly
// wherever a token is needed. Rejected — that's how key-name typos
// silently break "stay logged in" across app restarts.
// Pitfall a junior would hit: swallowing the exception here instead of
// rethrowing as CacheException — a silent Keystore failure would look
// like "user was never logged in" instead of a storage error worth
// surfacing distinctly to retry.
