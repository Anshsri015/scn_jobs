import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/services/app_preferences_service.dart';

final appPreferencesServiceProvider = Provider<AppPreferencesService>((ref) {
  return AppPreferencesService();
});

final notificationsEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(appPreferencesServiceProvider).getNotificationsEnabled();
});

final languageProvider = FutureProvider<String>((ref) {
  return ref.watch(appPreferencesServiceProvider).getLanguage();
});
