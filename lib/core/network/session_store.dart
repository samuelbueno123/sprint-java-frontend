import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'browser_credentials_stub.dart'
    if (dart.library.js_interop) 'browser_credentials_web.dart'
    as browser;

/// Mantém os tokens da sessão entre reinicializações e renova o acesso expirado.
class SessionStore {
  SessionStore._();

  static const _accessTokenKey = 'session.accessToken';
  static const _refreshTokenKey = 'session.refreshToken';
  static const _hasSessionKey = 'session.active';

  static String? _accessToken;
  static String? _refreshToken;
  static bool _hasSession = false;
  static Future<String?>? _refreshInFlight;

  static String? get accessToken => _accessToken;
  static bool get hasSession => _hasSession;

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _hasSession =
        preferences.getBool(_hasSessionKey) ??
        preferences.getString(_refreshTokenKey) != null;
    if (kIsWeb) {
      // Web refresh tokens stay in the HttpOnly cookie instead of localStorage.
      _accessToken = null;
      _refreshToken = null;
      return;
    }
    _accessToken = preferences.getString(_accessTokenKey);
    _refreshToken = preferences.getString(_refreshTokenKey);
  }

  static Future<void> setSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    _hasSession = accessToken.isNotEmpty && refreshToken.isNotEmpty;
    _accessToken = kIsWeb || accessToken.isEmpty ? null : accessToken;
    _refreshToken = kIsWeb || refreshToken.isEmpty ? null : refreshToken;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_hasSessionKey, _hasSession);
    if (kIsWeb || _accessToken == null) {
      await preferences.remove(_accessTokenKey);
    } else {
      await preferences.setString(_accessTokenKey, _accessToken!);
    }
    if (kIsWeb || _refreshToken == null) {
      await preferences.remove(_refreshTokenKey);
    } else {
      await preferences.setString(_refreshTokenKey, _refreshToken!);
    }
  }

  static Future<String?> refreshAccessToken() {
    return _refreshInFlight ??= _requestNewTokens().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  static Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _hasSession = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_accessTokenKey);
    await preferences.remove(_refreshTokenKey);
    await preferences.remove(_hasSessionKey);
  }

  static Future<String?> _requestNewTokens() async {
    final refreshToken = _refreshToken;
    if (!AppConfig.hasValidApiBaseUrl ||
        (!_hasSession && (refreshToken == null || refreshToken.isEmpty)) ||
        (!kIsWeb && (refreshToken == null || refreshToken.isEmpty))) {
      return null;
    }

    final client = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    browser.enableBrowserCredentials(client);

    try {
      final response = await client.post<Map<String, dynamic>>(
        Uri.parse(AppConfig.apiBaseUrl).resolve('/api/auth/refresh').toString(),
        data: kIsWeb ? null : {'refreshToken': refreshToken},
      );
      final body = response.data ?? const <String, dynamic>{};
      final accessToken = body['token'] as String? ?? '';
      final nextRefreshToken = body['refreshToken'] as String? ?? '';
      if (accessToken.isEmpty || nextRefreshToken.isEmpty) return null;

      await setSession(
        accessToken: accessToken,
        refreshToken: nextRefreshToken,
      );
      return accessToken;
    } on DioException catch (exception) {
      if (exception.response?.statusCode == 401 ||
          exception.response?.statusCode == 403) {
        await clear();
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
