import 'package:scn_jobs/domain/repositories/auth_repository.dart';

class ResendOtpUseCase {
  const ResendOtpUseCase(this._repository);
  final AuthRepository _repository;

  /// Returns the dev-only OTP on non-production backends, or null.
  Future<String?> call({required String phone}) {
    return _repository.resendOtp(phone: phone);
  }
}
