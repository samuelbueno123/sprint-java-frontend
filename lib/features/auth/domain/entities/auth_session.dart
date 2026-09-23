import 'authenticated_user.dart';
import 'user_role.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
    required this.profileType,
  });

  final String accessToken;
  final AuthenticatedUser user;
  final UserRole profileType;
}
