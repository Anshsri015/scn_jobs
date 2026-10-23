import 'package:scn_jobs/domain/entities/auth_session.dart';
import 'package:scn_jobs/domain/entities/register_result.dart';
import 'package:scn_jobs/domain/entities/user.dart';

abstract class AuthRepository {
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  /// Returns the new worker's userId plus, in non-production backend
  /// environments only, the OTP the backend generated (real SMS is
  /// currently disabled — see API docs §1.4). See `RegisterResult` and
  /// `DevOtpCache` for how this stays out of release builds.
  Future<RegisterResult> registerWorker({
    required String email,
    required String password,
    required String phone,
    String? name,
  });

  Future<AuthSession> verifyOtp({
    required String phone,
    required String otp,
  });

  /// Returns the dev-only OTP (non-production backends only) or null.
  Future<String?> resendOtp({required String phone});

  /// ✅ CONFIRMED against the API doc — the backend returns a real 404
  /// ("No account found with this email") when [email] isn't
  /// registered, and the doc explicitly says the frontend should show
  /// that message directly. So, unlike the more typical
  /// never-reveal-account-existence pattern, a failure here IS
  /// meaningful and should reach the user as-is — see
  /// `ForgotPasswordScreen`.
  Future<void> forgotPassword({required String email});

  /// Verifies the 6-digit [otp] emailed to [email] and sets
  /// [newPassword] in one call — this backend doesn't use a
  /// token-in-email-link flow. [otp] is single-use and expires 10
  /// minutes after `forgotPassword` was called.
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });

  Future<void> logout();

  /// Permanently deletes the account server-side, then clears the local
  /// session — same order as `logout()` (remote first, local after),
  /// so a failed remote delete never leaves the app thinking the
  /// account is gone when the server still has it.
  Future<void> deleteAccount();

  /// Null if no session exists locally. Otherwise fetches /api/auth/me
  /// to confirm the session is still valid server-side.
  Future<User?> currentUser();

  /// Day 14 — backs the splash/routing decision of whether a logged-in
  /// worker still needs to go through profile setup. Only call this
  /// once `currentUser()` has confirmed a session exists.
  Future<bool> needsOnboarding();
}