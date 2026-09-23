import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';

void main() {
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
}
