import 'package:shared_preferences/shared_preferences.dart';

/// Wraps `shared_preferences` for the two non-sensitive settings Day 19
/// needs. Never store tokens or anything security-sensitive here — that
/// stays in `SecureStorageService` (Keystore-backed).
class AppPreferencesService {
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _languageKey = 'language';

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, value);
  }

  /// 'en' or 'hi' — the app doesn't actually localize strings yet
  /// (no ARB files / intl_utils setup); this only persists the choice
  /// for whenever localization is added, so the setting isn't lost.
  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'en';
  }

  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }
}
