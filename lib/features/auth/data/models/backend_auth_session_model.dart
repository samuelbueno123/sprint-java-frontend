import '../../domain/entities/auth_session.dart';
import '../../domain/entities/authenticated_user.dart';

class BackendAuthSessionModel {
  const BackendAuthSessionModel({
    required this.accessToken,
    required this.user,
  });

  factory BackendAuthSessionModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    // O backend usa sessão via Cookie e não retorna 'accessToken' no corpo.
    // Usamos 'success' para indicar uma sessão ativa vinda do backend.
    final hasSession = json['success'] == true;

    return BackendAuthSessionModel(
      accessToken: hasSession ? 'session-active' : '',
      user: AuthenticatedUser(
        id: user['googleId']?.toString() ?? '',
        email: user['email'] as String? ?? '',
        name: user['name'] as String? ?? '',
        photoUrl: user['picture'] as String?,
      ),
    );
  }

  final String accessToken;
  final AuthenticatedUser user;

  AuthSession toEntity() => AuthSession(accessToken: accessToken, user: user);
}
