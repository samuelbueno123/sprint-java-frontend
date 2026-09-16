import 'app_environment.dart';

/// Configuração centralizada e injetada por `--dart-define` no build.
///
/// Exemplos:
/// `flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=https://api.dev.exemplo.com`
/// `flutter build web --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.exemplo.com`
class AppConfig {
  AppConfig._();

  static const _environmentValue = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
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

  static Uri get logoutEndpoint =>
      Uri.parse(apiBaseUrl).resolve('/api/auth/logout');

  static Uri studentByGoogleIdEndpoint(String googleId) =>
      Uri.parse(apiBaseUrl).resolve('/api/students/google/$googleId');

  static Uri studentByEmailEndpoint(String email) =>
      Uri.parse(apiBaseUrl).resolve('/api/students/email/$email');

  static Uri teacherByGoogleIdEndpoint(String googleId) =>
      Uri.parse(apiBaseUrl).resolve('/api/teachers/google/$googleId');

  static Uri teacherByEmailEndpoint(String email) =>
      Uri.parse(apiBaseUrl).resolve('/api/teachers/email/$email');
}
