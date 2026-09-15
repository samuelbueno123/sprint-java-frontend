import '../entities/auth_session.dart';
import '../entities/user_role.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle {
  const SignInWithGoogle(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call(UserRole role) => _repository.signInWithGoogle(role);
}
