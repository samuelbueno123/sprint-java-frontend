import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../models/home_response_model.dart';
import '../models/student_model.dart';
import '../models/teacher_model.dart';

class DashboardRemoteDataSource {
  const DashboardRemoteDataSource(this._dio);

  final Dio _dio;

  Future<HomeResponseModel> getHomeData() async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConfig.homeEndpoint.toString(),
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

  Future<void> logout() async {
    await _dio.post<Map<String, dynamic>>(AppConfig.logoutEndpoint.toString());
  }
}
