import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'browser_credentials_stub.dart'
    if (dart.library.js_interop) 'browser_credentials_web.dart'
    as browser;
import 'session_store.dart';

/// Cliente HTTP único. Features recebem repositórios, não URLs ou Dio diretamente.
class ApiClient {
  ApiClient() : dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)) {
    browser.enableBrowserCredentials(dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = SessionStore.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
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
          if (error.response?.statusCode != 401 ||
              request.extra['skipAuthRefresh'] == true ||
              isAuthRequest) {
            handler.next(error);
            return;
          }

          final accessToken = await SessionStore.refreshAccessToken();
          if (accessToken == null) {
            handler.next(error);
            return;
          }

          request
            ..headers['Authorization'] = 'Bearer $accessToken'
            ..extra['skipAuthRefresh'] = true;
          try {
            handler.resolve(await dio.fetch<dynamic>(request));
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );
  }

  final Dio dio;
}
