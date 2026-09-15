import '../entities/auth_session.dart';
import '../entities/user_role.dart';

abstract interface class AuthRepository {
  Future<AuthSession> signInWithGoogle(UserRole role);
  Future<void> signOutFromGoogle();
}
