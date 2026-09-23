import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/session_store.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user_role.dart';

/// Coordinates account creation with the profile endpoints already exposed by
/// the backend. The profile is created before the first login because student
/// and teacher records are the user records in the backend's joined hierarchy.
class RegistrationViewModel extends ChangeNotifier {
  RegistrationViewModel(this._remote);

  final AuthRemoteDataSource _remote;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<AuthSession> registerStudent({
    required String name,
    required String email,
    required String password,
    required List<String> languages,
  }) async {
    late AuthSession result;
    await _run(() async {
      _requireApiConfiguration();
      await _remote.createStudent(
        name: name,
        email: email,
        googleId: '',
        languages: languages,
      );
      result = await _authenticate(email, password);
      if (result.profileType != UserRole.student) {
        throw const RegistrationException(
          'O perfil foi criado, mas o backend não confirmou o acesso de aluno. Entre novamente.',
        );
      }
    });
    return result;
  }

  Future<AuthSession> registerTeacher({
    required String name,
    required String email,
    required String password,
    required int institutionId,
    required List<String> taughtLanguages,
    required List<String> specializationAreas,
    required String bibliography,
  }) async {
    late AuthSession result;
    await _run(() async {
      _requireApiConfiguration();
      await _remote.createTeacher(
        name: name,
        email: email,
        googleId: '',
        institutionId: institutionId,
        taughtLanguages: taughtLanguages,
        specializationAreas: specializationAreas,
        bibliography: bibliography,
      );
      result = await _authenticate(email, password);
      if (result.profileType != UserRole.teacher) {
        throw const RegistrationException(
          'O perfil foi criado, mas o backend não confirmou o acesso de professor. Entre novamente.',
        );
      }
    });
    return result;
  }

  Future<AuthSession> _authenticate(String email, String password) async {
    _requireApiConfiguration();
    final model = await _remote.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (model.accessToken.isEmpty || model.user.id.isEmpty) {
      throw const RegistrationException(
        'O backend retornou uma sessão inválida.',
      );
    }
    SessionStore.setAccessToken(model.accessToken);
    return model.toEntity();
  }

  void _requireApiConfiguration() {
    if (!AppConfig.hasValidApiBaseUrl) {
      throw const RegistrationException(
        'Configure API_BASE_URL antes de cadastrar uma conta.',
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _errorMessage = registrationErrorMessage(error);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

class RegistrationException implements Exception {
  const RegistrationException(this.message);
  final String message;
}

String registrationErrorMessage(Object error) {
  if (error is RegistrationException) return error.message;
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map<String, dynamic>) {
      final message = body['message'] ?? body['detail'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    if (error.response?.statusCode == 401 ||
        error.response?.statusCode == 403) {
      return 'Não foi possível autenticar. Confira o email e a senha.';
    }
    if (error.response?.statusCode == 409) {
      return 'Já existe um cadastro com estes dados.';
    }
    return 'Não foi possível concluir o cadastro. Verifique sua conexão e tente novamente.';
  }
  return 'Não foi possível concluir o cadastro. Tente novamente.';
}
