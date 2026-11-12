import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/session_store.dart';
import '../../../../core/localization/app_locale_controller.dart';
import '../../../../core/theme/app_theme_controller.dart';
import '../../../dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/google_identity_datasource.dart';
import '../models/backend_auth_session_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remote, {
    GoogleIdentityDataSource Function()? googleIdentityFactory,
    DashboardRemoteDataSource Function()? dashboardRemoteDataSourceFactory,
  }) : _googleIdentityFactory =
           googleIdentityFactory ?? GoogleIdentityDataSource.new,
       _dashboardRemoteDataSourceFactory =
           dashboardRemoteDataSourceFactory ??
           (() => DashboardRemoteDataSource(ApiClient().dio));

  final AuthRemoteDataSource _remote;
  final GoogleIdentityDataSource Function() _googleIdentityFactory;
  final DashboardRemoteDataSource Function() _dashboardRemoteDataSourceFactory;
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
      await SessionStore.clear();
    }
  }

  Future<AuthSession> _activateSession(BackendAuthSessionModel model) async {
    if (model.accessToken.isEmpty ||
        model.refreshToken.isEmpty ||
        model.user.id.isEmpty) {
      throw const AuthException('O backend retornou uma sessão inválida.');
    }
    await SessionStore.setSession(
      accessToken: model.accessToken,
      refreshToken: model.refreshToken,
    );

    try {
      final ds = _dashboardRemoteDataSourceFactory();
      final prefs = await ds.getMyPreferences();
      final themeStr = prefs['themeMode']?.toString().toLowerCase();
      if (themeStr == 'dark' || themeStr == 'light') {
        await AppThemeController.setMode(
          themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light,
        );
      }
      final lang = prefs['uiLanguage']?.toString();
      if (lang != null && lang.isNotEmpty) {
        await AppLocaleController.setLanguageCode(
          AppLocaleController.normalizeCode(lang),
        );
      }
    } catch (_) {
      // Preferences loading error in background does not block login
    }

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
