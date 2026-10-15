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

  Future<InstitutionModel> createInstitution(String name) async {
    final cleanName = name.trim();
    final slug = cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final response = await _dio.post<Map<String, dynamic>>(
      AppConfig.institutionsEndpoint.toString(),
      data: {
        'name': cleanName,
        'code': 'INST-${DateTime.now().millisecondsSinceEpoch}',
        'email': 'contato@${slug.isEmpty ? "instituicao" : slug}.edu.br',
        'active': true,
      },
    );
    return InstitutionModel.fromJson(response.data ?? const {});
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
