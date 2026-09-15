import '../../domain/entities/auth_session.dart';
import '../../domain/entities/authenticated_user.dart';

class BackendAuthSessionModel {
  const BackendAuthSessionModel({required this.accessToken, required this.user});

  factory BackendAuthSessionModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return BackendAuthSessionModel(
      accessToken: json['accessToken'] as String? ?? '',
      user: AuthenticatedUser(
        id: user['id']?.toString() ?? '',
        email: user['email'] as String? ?? '',
        name: user['name'] as String? ?? '',
        photoUrl: user['photoUrl'] as String?,
      ),
    );
  }

  final String accessToken;
  final AuthenticatedUser user;

  AuthSession toEntity() => AuthSession(accessToken: accessToken, user: user);
}
