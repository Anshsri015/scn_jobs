import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:scn_jobs/core/error/api_failure.dart';
import 'package:scn_jobs/core/error/exceptions.dart';
import 'package:scn_jobs/data/models/auth_response_model.dart';
import 'package:scn_jobs/domain/entities/register_result.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  /// Every endpoint here wraps its payload in `{ "data": {...} }`. This
  /// centralizes that unwrap with a type check instead of each method
  /// doing its own `!`/`as` cast — a malformed or missing `data` field
  /// now throws a catchable `ServerException` instead of crashing with
  /// an uncaught `TypeError`/`Null check operator` error.
  Map<String, dynamic> _unwrapData(Response<Map<String, dynamic>> response,
      String endpoint,) {
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw ServerException(
        'Unexpected response shape from $endpoint',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthResponseModel.fromJson(_unwrapData(response, '/auth/login'));
  }

  /// [RegisterResult.devOtp] is only ever present in non-production
  /// backend environments (API docs §1.4 — real SMS is currently
  /// disabled). Surfaced here, not dropped — see `register_result.dart`.
  Future<RegisterResult> registerWorker({
    required String email,
    required String password,
    required String phone,
    String? name,
  }) async {
    // TEMP DEBUG — investigating: register with a duplicate email
    // fails at verify-otp (not here), user goes back, corrects only
    // the email, resubmits with the SAME phone — and now gets told to
    // change the phone too, even though the phone was never the
    // problem. Logging the request + the raw error response (if any)
    // so we can see the backend's actual message/field instead of
    // guessing why phone gets flagged on the second attempt.
    //
    // kDebugMode-guarded: debugPrint is NOT stripped from release
    // builds on its own, so unguarded this was printing the worker's
    // email + phone (and, on response, their whole profile payload)
    // to release logcat on every device.
    if (kDebugMode) {
      debugPrint("=========== POST /auth/worker/register REQUEST ===========");
      debugPrint("email: $email | phone: $phone");
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/worker/register',
        data: {
          'email': email,
          'password': password,
          'phone': phone,
          // Doc-confirmed: `name` is optional on this endpoint. Only
          // sent when non-empty — an empty string isn't "no name", it's
          // a name, and would get stored as such server-side.
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
      );
      if (kDebugMode) {
        debugPrint("=========== POST /auth/worker/register RESPONSE (${response.statusCode}) ===========");
        debugPrint("${response.data}");
      }
      final data = _unwrapData(response, '/auth/worker/register');
      return RegisterResult(
        userId: data['userId'] as String,
        devOtp: data['devOtp'] as String?,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint("=========== POST /auth/worker/register ERROR (${e.response?.statusCode}) ===========");
        debugPrint("${e.response?.data}");
      }
      // ErrorInterceptor already mapped this to an ApiFailure and
      // attached it as `e.error` — but a bare `rethrow` here was
      // throwing the raw DioException instead, so every caller up the
      // chain (AsyncValue.guard in AuthController.register, then
      // RegisterScreen's `error is ValidationFailure` / `error is
      // ServerFailure` checks) was comparing against a DioException
      // that never matched any of those types. Unwrap it, same
      // pattern as `AuthRepositoryImpl.currentUser()`, so `state.error`
      // is the actual ApiFailure the rest of the app expects.
      final failure = e.error;
      if (failure is ApiFailure) throw failure;
      rethrow;
    }
  }

  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/worker/verify-otp',
      data: {'phone': phone, 'otp': otp},
    );
    return AuthResponseModel.fromJson(
      _unwrapData(response, 'auth/worker/verify-otp'),
    );
  }

  /// Returns the dev-only OTP echoed by non-production backends, or
  /// null in production (where SMS actually sends and the field is
  /// simply absent from the response).
  Future<String?> resendOtp({required String phone}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/worker/resend-otp',
      data: {'phone': phone},
    );
    final data = _unwrapData(response, '/api/auth/worker/resend-otp');
    return data['devOtp'] as String?;
  }

  /// ✅ CONFIRMED against the `SCN-Jobs-Forgot-Password` API doc — this
  /// endpoint DOES exist and genuinely returns 404 ("No account found
  /// with this email") for an unregistered email, which the doc says
  /// the frontend should show directly. Previously this swallowed
  /// every 404 as a silent success (written back when the endpoint's
  /// existence hadn't been confirmed yet) — now that the contract is
  /// confirmed, that swallow would just hide a real, doc-specified
  /// error from the user. Left un-swallowed like every other failure
  /// here; `ForgotPasswordScreen` is what decides how to display it.
  Future<void> forgotPassword({required String email}) async {
    await _dio.post<void>(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  /// ✅ CONFIRMED against the API doc — this is an OTP flow, not a
  /// token-in-email-link flow: `{ email, otp, newPassword }`, no
  /// `token` field at all. (Previously guessed as a `token`-based
  /// reset before the doc/Postman collection existed.)
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _dio.post<void>(
      '/auth/reset-password',
      data: {'email': email, 'otp': otp, 'newPassword': newPassword},
    );
  }

  Future<void> logout() async {
    await _dio.post<void>('/auth/logout');
  }

  /// ✅ CONFIRMED against the real API doc (§3, Worker Profile) —
  /// `DELETE /worker/account`, not `/auth/account` as originally
  /// guessed. Left in this class (rather than moved to
  /// `ProfileRemoteDataSource`) since `AuthRepository`/
  /// `DeleteAccountUseCase` already depend on it living here — moving
  /// it is a bigger refactor than this fix calls for.
  Future<void> deleteAccount() async {
    await _dio.delete<void>('/worker/account');
  }

  /// `GET /auth/me` — used on every app launch (splash) to check for
  /// an existing session.
  ///
  /// Timeout tuned for this specific backend: the dev API is hosted
  /// on Render's free tier (see `AppConfig.baseUrl`), which spins the
  /// service down after ~15 minutes of inactivity and takes anywhere
  /// from ~10-40s to "cold start" back up on the next request. A
  /// short timeout here (an earlier fix used 6s) fails a perfectly
  /// legitimate — just slow — cold-start response and forces the user
  /// to manually hit Retry every time the server was asleep. 25s
  /// covers the typical cold-start window while still being far
  /// short of the old default-timeout-plus-retries worst case
  /// (~48s), and `noRetry` stays on since stacking retries on top of
  /// a cold start only makes the wait longer, not more likely to
  /// succeed.
  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/me',
      options: Options(
        sendTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        // Base `connectTimeout` (15s, see dio_provider.dart) is
        // shorter than a Render cold start can take, so it's
        // overridden here too — otherwise the connection attempt
        // itself could time out before the 25s receive window ever
        // starts.
        connectTimeout: const Duration(seconds: 25),
        extra: {'noRetry': true},
      ),
    );
    return _unwrapData(response, '/auth/me');
  }

  /// `GET /auth/onboarding-status` — "Returns whether the worker needs
  /// to complete profile setup; useful for splash/routing logic" (API
  /// doc §1). Exact key name in the response `data` object isn't
  /// spelled out, so this checks the handful of plausible names
  /// defensively instead of assuming one and crashing on a mismatch.
  /// Returns `true` (needs onboarding) if none of them are present,
  /// since that's the safer default — sending an already-onboarded
  /// worker back through profile setup is a minor annoyance, silently
  /// skipping onboarding for someone who needs it is a broken app.
  /// `GET /auth/onboarding-status` — the doc-confirmed response shape
  /// (Section 3) is `{ "data": { "needsOnboarding": true } }`. Reads
  /// that key directly.
  ///
  /// WHY THIS CHANGED: the old implementation guessed across six
  /// possible key names and — critically — **defaulted to `true`**
  /// (`needs onboarding`) whenever none of them matched. If the real
  /// response ever had a shape this guesswork didn't anticipate (e.g.
  /// briefly during a backend deploy, or any envelope quirk), every
  /// worker would get permanently stuck being told to "complete your
  /// profile" — on Apply, and everywhere else that reads this — no
  /// matter how many times they actually saved their data. That
  /// silent always-true fallback is exactly the bug matching "profile
  /// setup karne ke baad bhi apply screen 'complete profile'
  /// dikhata hai".
  ///
  /// Now: trust the documented key. If it's genuinely missing,
  /// surface [OnboardingStatusUnknownException] instead of guessing —
  /// callers (see `onboardingStatusProvider`) fall back to the
  /// worker's own `profileComplete` flag from `GET /worker/profile`,
  /// a second, independently-confirmed source of truth, rather than
  /// this datasource silently making something up.
  Future<bool> getOnboardingStatus() async {
    final response =
    await _dio.get<Map<String, dynamic>>('/auth/onboarding-status');
    final data = _unwrapData(response, '/auth/onboarding-status');

    final value = data['needsOnboarding'];
    // TEMP DEBUG — investigating: right after finishing the full
    // profile-setup wizard (esp. resume upload, the last step), the
    // very first onboarding-status check still says "needs onboarding"
    // — Settings keeps showing "Complete your profile". Redoing the
    // whole flow a second time then works. Suspect the backend's
    // resume-upload webhook (which sets `resumeUrl` on the profile,
    // separately from the wizard's own PATCH calls — see
    // `ProfileRepositoryImpl.updateResumeUrl`'s doc) hasn't finished
    // by the time this fires, if `needsOnboarding` depends on it.
    // Logging with a timestamp so we can compare "just after resume
    // upload" vs "reopening Settings later" calls.
    if (kDebugMode) {
      debugPrint(
        "=========== GET /auth/onboarding-status — ${DateTime.now().toIso8601String()} — needsOnboarding: $value ===========",
      );
    }
    if (value is bool) return value;

    throw const OnboardingStatusUnknownException();
  }
}

/// Thrown when `/auth/onboarding-status` doesn't return the
/// doc-confirmed `needsOnboarding` boolean — signals the caller to
/// fall back to an independent source instead of guessing.
class OnboardingStatusUnknownException implements Exception {
  const OnboardingStatusUnknownException();
}