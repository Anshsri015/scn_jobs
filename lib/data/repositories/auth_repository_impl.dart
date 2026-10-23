import 'package:dio/dio.dart';
import 'package:scn_jobs/core/error/api_failure.dart';
import 'package:scn_jobs/core/storage/secure_storage_service.dart';
import 'package:scn_jobs/data/datasources/auth_remote_datasource.dart';
import 'package:scn_jobs/data/models/user_model.dart';
import 'package:scn_jobs/domain/entities/auth_session.dart';
import 'package:scn_jobs/domain/entities/register_result.dart';
import 'package:scn_jobs/domain/entities/user.dart';
import 'package:scn_jobs/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService secureStorageService,
  })  : _remoteDataSource = remoteDataSource,
        _secureStorageService = secureStorageService;

  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorageService;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _remoteDataSource.login(
      email: email,
      password: password,
    );
    await _secureStorageService.saveAccessToken(response.token);
    // Confirm the fresh token is actually accepted before the UI is
    // allowed to go to /home. A deactivated/deleted account must not
    // flash the home screen until a later call fails.
    try {
      await _remoteDataSource.me();
    } on DioException catch (e) {
      final failure = e.error;
      if (failure is UnauthorizedFailure) {
        await _secureStorageService.clearSession();
        throw const UnauthorizedFailure(
          'This account has been deleted. Please contact support.',
        );
      }
      // Network/server hiccup: keep the login, splash re-checks later.
    }
    return AuthSession(user: response.user.toEntity(), token: response.token);
  }

  @override
  Future<RegisterResult> registerWorker({
    required String email,
    required String password,
    required String phone,
    String? name,
  }) async {
    final result = await _remoteDataSource.registerWorker(
      email: email,
      password: password,
      phone: phone,
      name: name,
    );
    // Persist locally right away — see `SecureStorageService.
    // saveDisplayName`'s doc for why this can't just be re-fetched
    // later from `/auth/me`. Best-effort: a failure here shouldn't
    // block registration itself.
    if (name != null && name.trim().isNotEmpty) {
      await _secureStorageService.saveDisplayName(name.trim());
    }
    return result;
  }

  @override
  Future<AuthSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _remoteDataSource.verifyOtp(phone: phone, otp: otp);
    await _secureStorageService.saveAccessToken(response.token);
    return AuthSession(user: response.user.toEntity(), token: response.token);
  }

  @override
  Future<String?> resendOtp({required String phone}) {
    return _remoteDataSource.resendOtp(phone: phone);
  }

  @override
  Future<void> forgotPassword({required String email}) {
    return _remoteDataSource.forgotPassword(email: email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _remoteDataSource.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> logout() async {
    await _remoteDataSource.logout();
    await _secureStorageService.clearSession();
  }

  @override
  Future<void> deleteAccount() async {
    await _remoteDataSource.deleteAccount();
    await _secureStorageService.clearSession();
  }

  /// WHY THIS CHANGED: previously any failure from `GET /auth/me` —
  /// including a slow/unreachable API, not just an expired token —
  /// bubbled straight up. `SplashScreen` treated every error the same
  /// way and bounced the user to `/onboarding`, so a person with a
  /// perfectly valid saved session would get logged out purely
  /// because the network was slow. Now:
  /// - A real `401` (`UnauthorizedFailure`) means the session is
  ///   genuinely dead -> clear it and return null, same as before.
  /// - A `NetworkFailure`/timeout/`ServerFailure` does NOT clear the
  ///   session or return null — it rethrows a [SessionCheckException]
  ///   so the caller (splash) can tell "couldn't confirm" apart from
  ///   "confirmed logged out" and offer Retry instead of silently
  ///   routing to onboarding.
  @override
  Future<User?> currentUser() async {
    final hasSession = await _secureStorageService.hasSession;
    if (!hasSession) return null;

    try {
      final json = await _remoteDataSource.me();
      return UserModel.fromJson(json).toEntity();
    } on DioException catch (e) {
      final failure = e.error;
      if (failure is UnauthorizedFailure) {
        await _secureStorageService.clearSession();
        return null;
      }
      // Network/server/unknown failure — we genuinely don't know
      // whether the session is valid, so don't guess. Let the caller
      // decide (retry) instead of forcing onboarding.
      throw SessionCheckException(
        failure is ApiFailure ? failure.message : e.message ?? 'Network error',
      );
    }
  }

  @override
  Future<bool> needsOnboarding() {
    return _remoteDataSource.getOnboardingStatus();
  }
}

/// Thrown by [AuthRepositoryImpl.currentUser] when a local session
/// token exists but `/auth/me` couldn't confirm it due to a network/
/// server problem (as opposed to a real 401, which means the session
/// is actually dead). Callers like `SplashScreen` should offer Retry
/// on this instead of treating it as "not logged in".
class SessionCheckException implements Exception {
  const SessionCheckException(this.message);
  final String message;

  @override
  String toString() => 'SessionCheckException: $message';
}