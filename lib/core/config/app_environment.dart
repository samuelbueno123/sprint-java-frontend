/// Ambientes suportados pela aplicação.
enum AppEnvironment { development, staging, production }

class AppEnvironmentParser {
  const AppEnvironmentParser._();

  static AppEnvironment fromString(String value) {
    return switch (value.toLowerCase()) {
      'production' => AppEnvironment.production,
      'staging' || 'test' => AppEnvironment.staging,
      _ => AppEnvironment.development,
    };
  }
}
