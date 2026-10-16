import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../models/backend_auth_session_model.dart';

import '../models/institution_model.dart';

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

  Future<List<InstitutionModel>> fetchInstitutions([String? query]) async {
    final trimmed = query?.trim() ?? '';
    final url = trimmed.isNotEmpty
        ? AppConfig.institutionSearchByNameEndpoint(trimmed).toString()
        : AppConfig.institutionsEndpoint.toString();

    final response = await _dio.get<List<dynamic>>(url);
    final data = response.data ?? const [];
    return data
        .map((item) => InstitutionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> fetchLanguages() async {
    final response = await _dio.get<List<dynamic>>(
      AppConfig.languagesCatalogEndpoint.toString(),
    );
    return (response.data ?? const [])
        .map((value) => value.toString())
        .toList();
  }

  Future<List<String>> fetchProficiencyLevels() async {
    final response = await _dio.get<List<dynamic>>(
      AppConfig.proficiencyLevelsCatalogEndpoint.toString(),
    );
    return (response.data ?? const [])
        .map((value) => value.toString())
        .toList();
  }

  Future<void> requestInstitution({
    required String requestedName,
    required String requesterName,
    required String requesterEmail,
    String? city,
    String? state,
    String? message,
  }) async {
    await _dio.post<void>(
      Uri.parse(
        AppConfig.apiBaseUrl,
      ).resolve('/api/institutions/requests').toString(),
      data: {
        'requestedName': requestedName.trim(),
        'requesterName': requesterName.trim(),
        'requesterEmail': requesterEmail.trim().toLowerCase(),
        'city': city?.trim(),
        'state': state?.trim(),
        'message': message?.trim(),
      },
    );
  }

  Future<void> createStudent({
    required String name,
    required String email,
    required String password,
    required String googleId,
    required List<dynamic> languages,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      AppConfig.studentsEndpoint.toString(),
      data: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'googleId': googleId.isEmpty ? null : googleId,
        'languages': languages,
      },
    );
  }

  Future<void> createTeacher({
    required String name,
    required String email,
    required String password,
    required String googleId,
    required int institutionId,
    required List<String> taughtLanguages,
    required List<String> specializationAreas,
    required String bibliography,
    List<dynamic>? documents,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      AppConfig.teachersEndpoint.toString(),
      data: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'googleId': googleId.isEmpty ? null : googleId,
        'institutionId': institutionId,
        'taughtLanguages': taughtLanguages,
        'specializationAreas': specializationAreas,
        'bibliography': bibliography.trim(),
        'documents': documents,
      },
    );
  }
}
