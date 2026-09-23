import '../../../../core/network/session_store.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/student_enrollment.dart';
import '../../domain/entities/student_profile.dart';
import '../../domain/entities/teacher_class_assignment.dart';
import '../../domain/entities/teacher_profile.dart';
import '../../domain/entities/user_profile_type.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';
import '../models/teacher_model.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this._remoteDataSource);

  final DashboardRemoteDataSource _remoteDataSource;

  @override
  Future<DashboardData> getDashboardData() async {
    final home = await _remoteDataSource.getHomeData();

    StudentProfile? studentProfile;
    TeacherProfile? teacherProfile;
    var studentEnrollments = const <StudentEnrollment>[];
    var teacherAssignments = const <TeacherClassAssignment>[];

    if (home.profileType == UserProfileType.student) {
      if (home.user.googleId.isNotEmpty) {
        final model = await _remoteDataSource.getStudentByGoogleId(
          home.user.googleId,
        );
        studentProfile = model?.toEntity();
      }
      if (studentProfile == null && home.user.email.isNotEmpty) {
        final model = await _remoteDataSource.getStudentByEmail(
          home.user.email,
        );
        studentProfile = model?.toEntity();
      }
      if (studentProfile?.id != null) {
        try {
          studentEnrollments =
              (await _remoteDataSource.getActiveStudentEnrollments(
                studentProfile!.id!,
              )).map((enrollment) => enrollment.toEntity()).toList();
        } catch (_) {
          // The student's core profile remains available if enrollment data fails.
        }
      }
    } else if (home.profileType == UserProfileType.teacher) {
      TeacherModel? model;
      if (home.user.googleId.isNotEmpty) {
        model = await _remoteDataSource.getTeacherByGoogleId(
          home.user.googleId,
        );
      }
      if (model == null && home.user.email.isNotEmpty) {
        model = await _remoteDataSource.getTeacherByEmail(home.user.email);
      }
      if (model != null) {
        var institutionName = model.institution;
        if (model.institutionId != null) {
          try {
            institutionName =
                await _remoteDataSource.getInstitutionName(
                  model.institutionId!,
                ) ??
                institutionName;
          } catch (_) {
            // Keep the identifier from the profile if institution lookup fails.
          }
        }
        teacherProfile = model.toEntity(institutionName: institutionName);
        final teacherId = teacherProfile.id;
        if (teacherId != null) {
          try {
            teacherAssignments = (await _remoteDataSource.getTeacherAssignments(
              teacherId,
            )).map((assignment) => assignment.toEntity()).toList();
          } catch (_) {
            // The teacher profile remains usable without class history.
          }
        }
      }
    }

    final displayName = studentProfile?.name ?? teacherProfile?.name;

    return DashboardData(
      user: displayName == null || displayName.isEmpty
          ? home.user
          : home.user.copyWith(name: displayName),
      profileType: home.profileType,
      profileCompleted: home.profileCompleted,
      studentProfile: studentProfile,
      teacherProfile: teacherProfile,
      studentEnrollments: studentEnrollments,
      teacherAssignments: teacherAssignments,
    );
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } catch (_) {
      // Ignora erro do endpoint de logout para garantir que o cliente conclua o signout
    }
    SessionStore.clear();
  }
}
