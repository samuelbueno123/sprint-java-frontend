import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Cliente HTTP único. Features recebem repositórios, não URLs ou Dio diretamente.
class ApiClient {
  ApiClient() : dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

  final Dio dio;
}
