import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_environment.dart';

/// Configuração centralizada carregada do `.env` ou injetada por `--dart-define`.
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
  static String _envValue(String key) {
    const compileTimeValues = <String, String>{
      'API_BASE_URL': String.fromEnvironment('API_BASE_URL'),
      'GOOGLE_WEB_CLIENT_ID': String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      'GOOGLE_IOS_CLIENT_ID': String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
      'GOOGLE_SERVER_CLIENT_ID': String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
      ),
      'GOOGLE_ANDROID_CLIENT_ID': String.fromEnvironment(
        'GOOGLE_ANDROID_CLIENT_ID',
      ),
    };
    final compileTimeValue = compileTimeValues[key];
    if (compileTimeValue != null && compileTimeValue.isNotEmpty) {
      return compileTimeValue;
    }
    if (!dotenv.isInitialized) {
      return '';
    }
    return dotenv.env[key]?.trim() ?? '';
  }

  static String get apiBaseUrl => resolveApiBaseUrl();

  static String resolveApiBaseUrl({
    String? overrideUrl,
    String? environmentName,
    bool isWeb = kIsWeb,
    TargetPlatform? platform,
  }) {
    final configured = (overrideUrl ?? _envValue('API_BASE_URL')).trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    final envName = (environmentName ?? _environmentValue).trim().toLowerCase();
    if (envName != 'development') {
      return '';
    }
    final targetPlatform = platform ?? defaultTargetPlatform;
    if (!isWeb && targetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static String get googleWebClientId => _envValue('GOOGLE_WEB_CLIENT_ID');
  static String get googleIosClientId => _envValue('GOOGLE_IOS_CLIENT_ID');
  static String get googleServerClientId => _envValue('GOOGLE_SERVER_CLIENT_ID');
  static String get googleAndroidClientId =>
      _envValue('GOOGLE_ANDROID_CLIENT_ID');

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

  static Uri get institutionsEndpoint =>
      Uri.parse(apiBaseUrl).resolve('/api/institutions');

  static Uri get languagesCatalogEndpoint =>
      Uri.parse(apiBaseUrl).resolve('/api/catalog/languages');

  static Uri get proficiencyLevelsCatalogEndpoint =>
      Uri.parse(apiBaseUrl).resolve('/api/catalog/proficiency-levels');

  static Uri institutionSearchByNameEndpoint(String name) => Uri.parse(
    apiBaseUrl,
  ).resolve('/api/institutions/name/${Uri.encodeComponent(name)}');

  static Uri userUpdateEndpoint(String id) =>
      Uri.parse(apiBaseUrl).resolve('/api/users/$id');
}
