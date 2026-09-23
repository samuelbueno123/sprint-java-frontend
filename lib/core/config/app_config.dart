import 'package:flutter/foundation.dart';

import 'app_environment.dart';

/// Configuração centralizada e injetada por `--dart-define` no build.
///
/// Exemplos:
/// `flutter run --dart-define=APP_ENV=development --web-port=3000`
/// `flutter build web --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.exemplo.com`
class AppConfig {
  AppConfig._();

  static const _environmentValue = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (_environmentValue != 'development') return '';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static AppEnvironment get environment =>
      AppEnvironmentParser.fromString(_environmentValue);

  static bool get hasValidApiBaseUrl {
    final uri = Uri.tryParse(apiBaseUrl);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  /// Rotas da API.
  static Uri get googleAuthenticationEndpoint =>
      Uri.parse(apiBaseUrl).resolve('/api/auth/google');

  static Uri get homeEndpoint => Uri.parse(apiBaseUrl).resolve('/api/home');

  static Uri get authenticatedUserEndpoint =>
      Uri.parse(apiBaseUrl).resolve('/api/auth/me');

  static Uri get logoutEndpoint =>
      Uri.parse(apiBaseUrl).resolve('/api/auth/logout');

  static Uri get passwordAuthenticationEndpoint =>
      Uri.parse(apiBaseUrl).resolve('/api/auth/login');

  static Uri get studentsEndpoint =>
      Uri.parse(apiBaseUrl).resolve('/api/students');

  static Uri get teachersEndpoint =>
      Uri.parse(apiBaseUrl).resolve('/api/teachers');

  static Uri institutionEndpoint(int id) =>
      Uri.parse(apiBaseUrl).resolve('/api/institutions/$id');

  static Uri studentActiveEnrollmentsEndpoint(int studentId) => Uri.parse(
    apiBaseUrl,
  ).resolve('/api/students/$studentId/enrollments/active');

  static Uri teacherAssignmentsEndpoint(int teacherId) =>
      Uri.parse(apiBaseUrl).resolve('/api/teachers/$teacherId/assignments');

  static Uri studentByGoogleIdEndpoint(String googleId) =>
      Uri.parse(apiBaseUrl).resolve('/api/students/google/$googleId');

  static Uri studentByEmailEndpoint(String email) => Uri.parse(
    apiBaseUrl,
  ).resolve('/api/students/email/${Uri.encodeComponent(email)}');

  static Uri teacherByGoogleIdEndpoint(String googleId) =>
      Uri.parse(apiBaseUrl).resolve('/api/teachers/google/$googleId');

  static Uri teacherByEmailEndpoint(String email) => Uri.parse(
    apiBaseUrl,
  ).resolve('/api/teachers/email/${Uri.encodeComponent(email)}');
}
