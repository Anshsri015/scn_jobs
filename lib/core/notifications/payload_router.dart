/// Maps an FCM data payload to an in-app route.
///
/// ⚠️ Backend push-payload shape (`{ "type": "application_status_changed",
/// "applicationId": "..." }`) is a best-guess, not yet confirmed —
/// same caveat as Profile/Jobs/Master Data (Days 8/11/15). If the real
/// payload differs, only this file needs a fix.
class PayloadRouter {
  PayloadRouter._();

  static String? routeFor(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'application_status_changed':
        final applicationId = data['applicationId'] as String?;
        if (applicationId == null) return null;
        return '/applications/$applicationId';
      default:
        return null;
    }
  }
}
