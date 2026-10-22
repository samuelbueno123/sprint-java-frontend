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

  Future<StudentModel?> getOwnStudentProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        Uri.parse(AppConfig.apiBaseUrl).resolve('/api/students/me').toString(),
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

  Future<TeacherModel?> getOwnTeacherProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        Uri.parse(AppConfig.apiBaseUrl).resolve('/api/teachers/me').toString(),
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

  Future<void> updateProfilePicture({
    String? userId,
    required String profilePicture,
  }) async {
    final endpoint = AppConfig.authenticatedUserEndpoint.toString();

    await _dio.put<void>(endpoint, data: {'profilePicture': profilePicture});
  }

  Future<void> updateProfileDetails({
    String? userId,
    String? name,
    String? email,
  }) async {
    final endpoint = AppConfig.authenticatedUserEndpoint.toString();

    final Map<String, dynamic> body = {};
    if (name != null && name.trim().isNotEmpty) body['name'] = name.trim();
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim().toLowerCase();
    }

    await _dio.put<void>(endpoint, data: body);
  }

  Future<void> updatePassword({
    String? userId,
    required String currentPassword,
    required String password,
  }) async {
    final endpoint = AppConfig.authenticatedUserEndpoint.toString();

    await _dio.put<void>(
      endpoint,
      data: {'currentPassword': currentPassword, 'password': password},
    );
  }

  Future<void> updateUser({
    String? userId,
    required String name,
    required String email,
    String? googleId,
    String? profilePicture,
    String? currentPassword,
    String? password,
  }) async {
    final endpoint = (userId != null && userId.isNotEmpty)
        ? AppConfig.userUpdateEndpoint(userId).toString()
        : AppConfig.authenticatedUserEndpoint.toString();

    final Map<String, dynamic> body = {};
    if (name.trim().isNotEmpty) body['name'] = name.trim();
    if (email.trim().isNotEmpty) body['email'] = email.trim().toLowerCase();
    if (googleId != null && googleId.isNotEmpty) body['googleId'] = googleId;
    if (profilePicture != null && profilePicture.isNotEmpty) {
      body['profilePicture'] = profilePicture;
    }
    if (currentPassword != null && currentPassword.isNotEmpty) {
      body['currentPassword'] = currentPassword;
    }
    if (password != null && password.isNotEmpty) body['password'] = password;

    await _dio.put<void>(endpoint, data: body);
  }

  Future<int> getUnreadNotificationsCount() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        Uri.parse(
          AppConfig.apiBaseUrl,
        ).resolve('/api/admin/notifications/unread-count').toString(),
      );
      return (response.data?['unreadCount'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Uri.parse(AppConfig.apiBaseUrl)
          .resolve('/api/auth/forgot-password')
          .toString(),
      data: {'email': email.trim().toLowerCase()},
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Uri.parse(AppConfig.apiBaseUrl)
          .resolve('/api/auth/reset-password')
          .toString(),
      data: {
        'email': email.trim().toLowerCase(),
        'token': token.trim(),
        'newPassword': newPassword,
      },
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> getMyPreferences() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Uri.parse(AppConfig.apiBaseUrl)
          .resolve('/api/auth/me/preferences')
          .toString(),
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> updateMyPreferences({
    String? uiLanguage,
    String? themeMode,
    int? dailyGoalMinutes,
    bool? notifDailyReminders,
    bool? notifAchievements,
    bool? notifRanking,
    bool? notifClassUpdates,
  }) async {
    final Map<String, dynamic> body = {};
    if (uiLanguage != null) body['uiLanguage'] = uiLanguage;
    if (themeMode != null) body['themeMode'] = themeMode;
    if (dailyGoalMinutes != null) body['dailyGoalMinutes'] = dailyGoalMinutes;
    if (notifDailyReminders != null) {
      body['notifDailyReminders'] = notifDailyReminders;
    }
    if (notifAchievements != null) {
      body['notifAchievements'] = notifAchievements;
    }
    if (notifRanking != null) body['notifRanking'] = notifRanking;
    if (notifClassUpdates != null) {
      body['notifClassUpdates'] = notifClassUpdates;
    }

    final response = await _dio.put<Map<String, dynamic>>(
      Uri.parse(AppConfig.apiBaseUrl)
          .resolve('/api/auth/me/preferences')
          .toString(),
      data: body,
    );
    return response.data ?? const {};
  }

  Future<void> deleteMyAccount({
    String? currentPassword,
    String? confirmationText,
  }) async {
    await _dio.delete<void>(
      AppConfig.authenticatedUserEndpoint.toString(),
      data: {
        if (currentPassword != null && currentPassword.isNotEmpty)
          'currentPassword': currentPassword,
        if (confirmationText != null && confirmationText.isNotEmpty)
          'confirmationText': confirmationText,
      },
    );
  }

  Future<Map<String, dynamic>> getMyProgressSummary({String? timezone}) async {
    final baseUri = Uri.parse(AppConfig.apiBaseUrl)
        .resolve('/api/exercises/progress/me');
    final uri = (timezone != null && timezone.trim().isNotEmpty)
        ? baseUri.replace(queryParameters: {'timezone': timezone.trim()})
        : baseUri;
    final response = await _dio.get<Map<String, dynamic>>(uri.toString());
    return response.data ?? const {};
  }

  Future<List<Map<String, dynamic>>> generateExerciseQuestionsWithAi({
    required String languageName,
    required String proficiencyLevel,
    required String category,
    required String theme,
    int questionCount = 3,
    List<String>? questionStyles,
    String? additionalInstructions,
  }) async {
    final response = await _dio.post<List<dynamic>>(
      Uri.parse(AppConfig.apiBaseUrl)
          .resolve('/api/exercises/generate-ai')
          .toString(),
      data: {
        'languageName': languageName,
        'proficiencyLevel': proficiencyLevel,
        'category': category,
        'theme': theme,
        'questionCount': questionCount,
        if (questionStyles != null && questionStyles.isNotEmpty)
          'questionStyles': questionStyles,
        if (additionalInstructions != null &&
            additionalInstructions.trim().isNotEmpty)
          'additionalInstructions': additionalInstructions.trim(),
      },
    );
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> logout() async {
    await _dio.post<Map<String, dynamic>>(AppConfig.logoutEndpoint.toString());
  }
}
