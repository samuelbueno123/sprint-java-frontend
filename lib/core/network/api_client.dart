import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'session_store.dart';

/// Cliente HTTP único. Features recebem repositórios, não URLs ou Dio diretamente.
class ApiClient {
  ApiClient()
    : dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final token = SessionStore.accessToken;
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
          ),
        );

  final Dio dio;
}
