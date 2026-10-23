import 'package:scn_jobs/domain/repositories/auth_repository.dart';

class ForgotPasswordUseCase {
  const ForgotPasswordUseCase(this._repository);
  final AuthRepository _repository;

  Future<void> call({required String email}) {
    return _repository.forgotPassword(email: email);
  }
}
