import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/google_identity_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._googleIdentity, this._remote);

  final GoogleIdentityDataSource _googleIdentity;
  final AuthRemoteDataSource _remote;

  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleIdentity.onCurrentUserChanged;

  @override
  Future<AuthSession> signInWithIdToken(String idToken, UserRole role) async {
    final session = await _remote.exchangeGoogleIdToken(
      idToken: idToken,
      role: role.apiValue,
    );
    if (session.accessToken.isEmpty || session.user.id.isEmpty) {
      throw const AuthException('O backend retornou uma sessão inválida.');
    }
    return session.toEntity();
  }

  @override
  Future<AuthSession> signInWithGoogle(UserRole role) async {
    if (!_googleIdentity.isConfigured) {
      throw const AuthException(
        'A autenticação Google não está configurada para este ambiente.',
      );
    }
    final idToken = await _googleIdentity.authenticateAndGetIdToken();
    if (idToken == null)
      throw const AuthException('Login com Google cancelado.');

    final session = await _remote.exchangeGoogleIdToken(
      idToken: idToken,
      role: role.apiValue,
    );
    if (session.accessToken.isEmpty || session.user.id.isEmpty) {
      throw const AuthException('O backend retornou uma sessão inválida.');
    }
    return session.toEntity();
  }

  @override
  Future<void> signOutFromGoogle() => _googleIdentity.signOut();
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

String authenticationErrorMessage(Object error) {
  if (error is AuthException) return error.message;
  if (error is DioException) {
    if (error.response?.statusCode == 401 ||
        error.response?.statusCode == 403) {
      return 'O backend não autorizou esta conta para o perfil selecionado.';
    }
    return 'Não foi possível concluir a autenticação com o servidor.';
  }
  return 'Não foi possível concluir o login com Google.';
}
