import 'package:scn_jobs/domain/entities/auth_session.dart';
import 'package:scn_jobs/domain/repositories/auth_repository.dart';

class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);
  final AuthRepository _repository;

  Future<AuthSession> call({
    required String phone,
    required String otp,
  }) {
    return _repository.verifyOtp(phone: phone, otp: otp);
  }
}
