import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../models/home_response_model.dart';
import '../models/student_model.dart';
import '../models/teacher_model.dart';
import '../models/student_enrollment_model.dart';
import '../models/teacher_class_assignment_model.dart';

class DashboardRemoteDataSource {
  const DashboardRemoteDataSource(this._dio);

  final Dio _dio;

  Future<HomeResponseModel> getHomeData() async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConfig.authenticatedUserEndpoint.toString(),
    );
    return HomeResponseModel.fromJson(response.data ?? const {});
  }

  Future<StudentModel?> getStudentByGoogleId(String googleId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConfig.studentByGoogleIdEndpoint(googleId).toString(),
      );
      if (response.data != null) {
        return StudentModel.fromJson(response.data!);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
    return null;
  }

  Future<StudentModel?> getStudentByEmail(String email) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConfig.studentByEmailEndpoint(email).toString(),
      );
      if (response.data != null) {
        return StudentModel.fromJson(response.data!);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
    return null;
  }

  Future<TeacherModel?> getTeacherByGoogleId(String googleId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConfig.teacherByGoogleIdEndpoint(googleId).toString(),
      );
      if (response.data != null) {
        return TeacherModel.fromJson(response.data!);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
    return null;
  }

  Future<TeacherModel?> getTeacherByEmail(String email) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConfig.teacherByEmailEndpoint(email).toString(),
      );
      if (response.data != null) {
        return TeacherModel.fromJson(response.data!);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
    return null;
  }

  Future<String?> getInstitutionName(int institutionId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConfig.institutionEndpoint(institutionId).toString(),
      );
      return response.data?['name'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<StudentEnrollmentModel>> getActiveStudentEnrollments(
    int studentId,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      AppConfig.studentActiveEnrollmentsEndpoint(studentId).toString(),
    );
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StudentEnrollmentModel.fromJson)
        .toList();
  }

  Future<List<TeacherClassAssignmentModel>> getTeacherAssignments(
    int teacherId,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      AppConfig.teacherAssignmentsEndpoint(teacherId).toString(),
    );
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TeacherClassAssignmentModel.fromJson)
        .toList();
  }

  Future<void> logout() async {
    await _dio.post<Map<String, dynamic>>(AppConfig.logoutEndpoint.toString());
  }
}
