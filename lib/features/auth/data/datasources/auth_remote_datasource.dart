import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../models/backend_auth_session_model.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<BackendAuthSessionModel> exchangeGoogleIdToken({
    required String idToken,
    required String role,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConfig.googleAuthenticationEndpoint.path,
      data: {'idToken': idToken, 'role': role},
    );
    return BackendAuthSessionModel.fromJson(response.data ?? const {});
  }
}
