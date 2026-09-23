import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/network/session_store.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/google_identity_datasource.dart';
import '../models/backend_auth_session_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remote, {
    GoogleIdentityDataSource Function()? googleIdentityFactory,
  }) : _googleIdentityFactory =
           googleIdentityFactory ?? GoogleIdentityDataSource.new;

  final AuthRemoteDataSource _remote;
  final GoogleIdentityDataSource Function() _googleIdentityFactory;
  GoogleIdentityDataSource? _googleIdentity;

  GoogleIdentityDataSource get _identity =>
      _googleIdentity ??= _googleIdentityFactory();

  @override
  Future<AuthSession> signInWithPassword(String email, String password) async {
    final session = await _remote.signInWithPassword(
      email: email,
      password: password,
    );
    return _activateSession(session);
  }

  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _identity.onCurrentUserChanged;

  @override
  Future<AuthSession> signInWithIdToken(String idToken) async {
    final session = await _remote.exchangeGoogleIdToken(idToken: idToken);
    return _activateSession(session);
  }

  @override
  Future<AuthSession> signInWithGoogle() async {
    if (!GoogleIdentityDataSource.isConfiguredForCurrentPlatform) {
      throw AuthException(GoogleIdentityDataSource.missingConfigurationMessage);
    }
    final idToken = await _identity.authenticateAndGetIdToken();
    if (idToken == null) {
      throw const AuthException('Login com Google cancelado.');
    }

    final session = await _remote.exchangeGoogleIdToken(idToken: idToken);
    return _activateSession(session);
  }

  @override
  Future<void> signOutFromGoogle() async {
    try {
      await _identity.signOut();
    } finally {
      SessionStore.clear();
    }
  }

  AuthSession _activateSession(BackendAuthSessionModel model) {
    if (model.accessToken.isEmpty || model.user.id.isEmpty) {
      throw const AuthException('O backend retornou uma sessão inválida.');
    }
    SessionStore.setAccessToken(model.accessToken);
    return model.toEntity();
  }
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
    final body = error.response?.data;
    if (body is Map<String, dynamic>) {
      final message = body['message'] ?? body['detail'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    if (error.response?.statusCode == 401 ||
        error.response?.statusCode == 403) {
      return 'A autenticação foi recusada. Confira os dados e tente novamente.';
    }
    return 'Não foi possível concluir a autenticação com o servidor.';
  }
  return 'Não foi possível concluir a autenticação.';
}
