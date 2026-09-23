import 'package:google_sign_in/google_sign_in.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle {
  const SignInWithGoogle(this._repository);

  final AuthRepository _repository;

  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _repository.onCurrentUserChanged;

  Future<AuthSession> call() => _repository.signInWithGoogle();

  Future<AuthSession> withIdToken(String idToken) =>
      _repository.signInWithIdToken(idToken);
}
