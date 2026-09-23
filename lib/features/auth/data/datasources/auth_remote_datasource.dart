import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../models/backend_auth_session_model.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<BackendAuthSessionModel> exchangeGoogleIdToken({
    required String idToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConfig.googleAuthenticationEndpoint.toString(),
      data: {'credential': idToken},
    );
    return BackendAuthSessionModel.fromJson(response.data ?? const {});
  }

  Future<BackendAuthSessionModel> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConfig.passwordAuthenticationEndpoint.toString(),
      data: {'email': email.trim(), 'password': password},
    );
    return BackendAuthSessionModel.fromJson(response.data ?? const {});
  }

  Future<void> createStudent({
    required String name,
    required String email,
    required String googleId,
    required List<String> languages,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      AppConfig.studentsEndpoint.toString(),
      data: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'googleId': googleId.isEmpty ? null : googleId,
        'languages': languages,
      },
    );
  }

  Future<void> createTeacher({
    required String name,
    required String email,
    required String googleId,
    required int institutionId,
    required List<String> taughtLanguages,
    required List<String> specializationAreas,
    required String bibliography,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      AppConfig.teachersEndpoint.toString(),
      data: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'googleId': googleId.isEmpty ? null : googleId,
        'institutionId': institutionId,
        'taughtLanguages': taughtLanguages,
        'specializationAreas': specializationAreas,
        'bibliography': bibliography.trim(),
      },
    );
  }
}
