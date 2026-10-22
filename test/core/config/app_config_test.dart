import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  test('uses the platform-appropriate backend URL in development', () {
    final expectedUrl =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080';
    expect(AppConfig.apiBaseUrl, expectedUrl);
    expect(AppConfig.hasValidApiBaseUrl, isTrue);
  });

  test('uses the Android emulator host for the development backend', () {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      expect(AppConfig.apiBaseUrl, 'http://10.0.2.2:8080');
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });

  test('respects API_BASE_URL from .env or explicit override', () {
    dotenv.loadFromString(envString: 'API_BASE_URL=https://api.duolinfo.edu.br');
    expect(AppConfig.apiBaseUrl, 'https://api.duolinfo.edu.br');

    expect(
      AppConfig.resolveApiBaseUrl(
        overrideUrl: 'http://192.168.1.50:8080',
        platform: TargetPlatform.android,
      ),
      'http://192.168.1.50:8080',
    );
  });

  test('requires explicit API_BASE_URL in production environment', () {
    expect(
      AppConfig.resolveApiBaseUrl(environmentName: 'production'),
      isEmpty,
    );
    expect(
      AppConfig.resolveApiBaseUrl(
        environmentName: 'production',
        overrideUrl: 'https://prod.duolinfo.edu.br',
      ),
      'https://prod.duolinfo.edu.br',
    );
  });
}
