import '../../domain/entities/auth_session.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/entities/user_role.dart';

class BackendAuthSessionModel {
  const BackendAuthSessionModel({
    required this.accessToken,
    required this.user,
    required this.profileType,
  });

  factory BackendAuthSessionModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return BackendAuthSessionModel(
      accessToken: json['token'] as String? ?? '',
      user: AuthenticatedUser(
        id: user['id']?.toString() ?? '',
        email: user['email'] as String? ?? '',
        name: user['name'] as String? ?? '',
        googleId: user['googleId'] as String? ?? '',
        photoUrl:
            user['profilePicture'] as String? ?? user['picture'] as String?,
      ),
      profileType: UserRole.fromApiValue(json['profileType'] as String?),
    );
  }

  final String accessToken;
  final AuthenticatedUser user;
  final UserRole profileType;

  AuthSession toEntity() => AuthSession(
    accessToken: accessToken,
    user: user,
    profileType: profileType,
  );
}
