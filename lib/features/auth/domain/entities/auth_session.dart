import 'authenticated_user.dart';
import 'user_role.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
    required this.profileType,
    this.refreshToken = '',
  });

  final String accessToken;
  final String refreshToken;
  final AuthenticatedUser user;
  final UserRole profileType;
}
