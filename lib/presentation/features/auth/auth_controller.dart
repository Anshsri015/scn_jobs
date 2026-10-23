import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/utils/dev_otp_cache.dart';
import 'package:scn_jobs/domain/entities/auth_session.dart';
import 'package:scn_jobs/domain/entities/register_result.dart';
import 'package:scn_jobs/domain/usecases/forgot_password_usecase.dart';
import 'package:scn_jobs/domain/usecases/login_usecase.dart';
import 'package:scn_jobs/domain/usecases/register_usecase.dart';
import 'package:scn_jobs/domain/usecases/resend_otp_usecase.dart';
import 'package:scn_jobs/domain/usecases/reset_password_usecase.dart';
import 'package:scn_jobs/domain/usecases/verify_otp_usecase.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';

/// Holds state for in-flight login / register / verify-otp / forgot /
/// reset actions. Session *restore* on app start is a separate concern
/// — see `authStateProvider`, which calls `AuthRepository.currentUser()`.
/// Logout is deliberately NOT here — see `AccountController`.
class AuthController extends AsyncNotifier<AuthSession?> {
  late final LoginUseCase _loginUseCase;
  late final RegisterUseCase _registerUseCase;
  late final VerifyOtpUseCase _verifyOtpUseCase;
  late final ResendOtpUseCase _resendOtpUseCase;
  late final ForgotPasswordUseCase _forgotPasswordUseCase;
  late final ResetPasswordUseCase _resetPasswordUseCase;

  @override
  Future<AuthSession?> build() async {
    final repo = ref.read(authRepositoryProvider);
    _loginUseCase = LoginUseCase(repo);
    _registerUseCase = RegisterUseCase(repo);
    _verifyOtpUseCase = VerifyOtpUseCase(repo);
    _resendOtpUseCase = ResendOtpUseCase(repo);
    _forgotPasswordUseCase = ForgotPasswordUseCase(repo);
    _resetPasswordUseCase = ResetPasswordUseCase(repo);
    return null;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
          () => _loginUseCase(email: email, password: password),
    );
    if (state.hasValue) {
      // Fresh session ban gaya — authStateProvider ko refresh karo taaki
      // route_guards/splash turant naya user dekhein, agli app-restart
      // ka wait na karna pade.
      ref.invalidate(authStateProvider);
    }
  }

  /// Returns the new [RegisterResult] on success, null on failure (the
  /// error is in `state`, same convention as before). On success, also
  /// caches `result.devOtp` (if any) into [DevOtpCache] keyed by
  /// [phone] — `VerifyOtpScreen` reads it from there via its own
  /// `widget.phone`, so no new navigation/route params are needed to
  /// get the dev-only OTP to the screen that needs it.
  Future<RegisterResult?> register({
    required String email,
    required String password,
    required String phone,
    String? name,
  }) async {
    state = const AsyncValue.loading();
    RegisterResult? result;
    state = await AsyncValue.guard<AuthSession?>(() async {
      result = await _registerUseCase(
        email: email,
        password: password,
        phone: phone,
        name: name,
      );
      DevOtpCache.store(phone, result?.devOtp);
      return null; // login sirf verify-otp ke baad hota hai
    });
    return result;
  }

  Future<void> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
          () => _verifyOtpUseCase(phone: phone, otp: otp),
    );
    if (state.hasValue) {
      ref.invalidate(authStateProvider);
    }
  }

  /// Errors yahan se thrown exception ke through surface hote hain, `state`
  /// ke through nahi — resend fail hone pe verify-otp screen ka apna
  /// loading/error UI overwrite nahi hona chahiye, us mein sirf OTP field
  /// aur verify button ka state hona chahiye, resend alag hai.
  ///
  /// On success, refreshes [DevOtpCache] for [phone] with the newly
  /// issued OTP (each resend invalidates the previous one server-side,
  /// so the cached value must be replaced, not left stale).
  Future<void> resendOtp({required String phone}) async {
    final devOtp = await _resendOtpUseCase(phone: phone);
    DevOtpCache.store(phone, devOtp);
  }

  /// A failure here (surfaced via `state.hasError`) is real and
  /// meaningful — including a 404 meaning [email] isn't registered,
  /// which the API doc says to show to the user directly. See
  /// `AuthRepository.forgotPassword`.
  Future<void> forgotPassword({required String email}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard<AuthSession?>(() async {
      await _forgotPasswordUseCase(email: email);
      return null;
    });
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard<AuthSession?>(() async {
      await _resetPasswordUseCase(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
      return null;
    });
  }
}

final authControllerProvider =
AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);