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

  /// A feature de autenticação conhece somente esta rota relativa.
  static Uri get googleAuthenticationEndpoint =>
      Uri.parse(apiBaseUrl).resolve('/api/auth/google');
}
