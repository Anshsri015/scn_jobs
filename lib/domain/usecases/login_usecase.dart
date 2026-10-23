import 'package:scn_jobs/domain/entities/auth_session.dart';
import 'package:scn_jobs/domain/repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<AuthSession> call({
    required String email,
    required String password,
  }) {
    return _repository.login(email: email, password: password);
  }
}
