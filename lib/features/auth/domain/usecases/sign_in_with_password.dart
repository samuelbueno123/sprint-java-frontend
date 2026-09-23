import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class SignInWithPassword {
  const SignInWithPassword(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call(String email, String password) =>
      _repository.signInWithPassword(email, password);
}
