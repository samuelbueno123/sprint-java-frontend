import 'package:google_sign_in/google_sign_in.dart';
import '../entities/auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession> signInWithPassword(String email, String password);
  Future<AuthSession> signInWithGoogle();
  Future<AuthSession> signInWithIdToken(String idToken);
  Future<void> signOutFromGoogle();
  Stream<GoogleSignInAccount?> get onCurrentUserChanged;
}
