import 'package:google_sign_in/google_sign_in.dart';
import '../entities/auth_session.dart';
import '../entities/user_role.dart';

abstract interface class AuthRepository {
  Future<AuthSession> signInWithGoogle(UserRole role);
  Future<AuthSession> signInWithIdToken(String idToken, UserRole role);
  Future<void> signOutFromGoogle();
  Stream<GoogleSignInAccount?> get onCurrentUserChanged;
}
