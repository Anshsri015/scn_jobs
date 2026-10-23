import 'package:scn_jobs/domain/entities/user.dart';

/// Pairs the logged-in [User] with their auth [token].
///
/// The backend also sets a session cookie automatically (CookieManager,
/// Day 3), but we additionally persist this token for use as a Bearer
/// header via AuthInterceptor — a fallback in case cookie support ever
/// breaks on a given platform/WebView.
class AuthSession {
  const AuthSession({required this.user, required this.token});

  final User user;
  final String token;
}
