import 'dart:math';
import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'browser_credentials_stub.dart'
    if (dart.library.js_interop) 'browser_credentials_web.dart'
    as browser;
import 'session_store.dart';

/// Cliente HTTP único com suporte a correlation ID, timeouts resilientes
/// e recuperação automática de sessão.
class ApiClient {
  ApiClient()
    : dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 15),
        ),
      ) {
    browser.enableBrowserCredentials(dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = SessionStore.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Injeta correlation ID para rastreabilidade de ponta a ponta
          if (!options.headers.containsKey('X-Correlation-Id')) {
            final correlationId = _generateCorrelationId();
            options.headers['X-Correlation-Id'] = correlationId;
            options.headers['X-Request-Id'] = correlationId;
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final isAuthRequest =
              request.path.contains('/api/auth/login') ||
              request.path.contains('/api/auth/google') ||
              request.path.contains('/api/auth/refresh') ||
              request.path.contains('/api/auth/logout');

          if (error.response?.statusCode == 401 &&
              request.extra['skipAuthRefresh'] != true &&
              !isAuthRequest) {
            final accessToken = await SessionStore.refreshAccessToken();
            if (accessToken != null) {
              request
                ..headers['Authorization'] = 'Bearer $accessToken'
                ..extra['skipAuthRefresh'] = true;
              try {
                handler.resolve(await dio.fetch<dynamic>(request));
                return;
              } on DioException catch (retryError) {
                handler.next(retryError);
                return;
              }
            } else {
              // Sessão expirou definitivamente e não pôde ser renovada
              SessionStore.notifySessionExpired();
              await SessionStore.clear();
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;

  static String _generateCorrelationId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randSuffix = random
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    return 'req-$timestamp-$randSuffix';
  }
}
