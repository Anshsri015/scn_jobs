import 'package:scn_jobs/domain/entities/register_result.dart';
import 'package:scn_jobs/domain/repositories/auth_repository.dart';

class RegisterUseCase {
  const RegisterUseCase(this._repository);
  final AuthRepository _repository;

  /// Returns the new worker's userId, plus a dev-only OTP on
  /// non-production backends — see `RegisterResult`.
  ///
  /// [name] is optional per the doc (`POST /auth/worker/register`)
  /// but the app always collects it on `RegisterScreen` now, so
  /// `PersonalDetailsScreen` can prefill it later — see
  /// `SecureStorageService.saveDisplayName` for why that's the only
  /// reliable way, since `GET /auth/me` never echoes name back.
  Future<RegisterResult> call({
    required String email,
    required String password,
    required String phone,
    String? name,
  }) {
    return _repository.registerWorker(
      email: email,
      password: password,
      phone: phone,
      name: name,
    );
  }
}
