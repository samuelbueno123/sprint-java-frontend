import '../repositories/auth_repository.dart';

class SignOutFromGoogle {
  const SignOutFromGoogle(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOutFromGoogle();
}
