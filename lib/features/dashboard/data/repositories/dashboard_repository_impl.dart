import '../../../../core/network/session_store.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/student_enrollment.dart';
import '../../domain/entities/student_profile.dart';
import '../../domain/entities/teacher_class_assignment.dart';
import '../../domain/entities/teacher_profile.dart';
import '../../domain/entities/user_profile_type.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this._remoteDataSource);

  final DashboardRemoteDataSource _remoteDataSource;

  @override
  Future<DashboardData> getDashboardData() async {
    final home = await _remoteDataSource.getHomeData();

    StudentProfile? studentProfile;
    TeacherProfile? teacherProfile;
    var hasTeacherProfile = false;
    var teacherApprovalPending = false;
    var studentEnrollments = const <StudentEnrollment>[];
    var teacherAssignments = const <TeacherClassAssignment>[];

    if (home.availableProfileTypes.contains(UserProfileType.student)) {
      final model = await _remoteDataSource.getOwnStudentProfile();
      studentProfile = model?.toEntity();
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
    }
    if (home.availableProfileTypes.contains(UserProfileType.teacher)) {
      final model = await _remoteDataSource.getOwnTeacherProfile();
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
    if (home.profileType == UserProfileType.user && teacherProfile == null) {
      final teacher = await _remoteDataSource.getOwnTeacherProfile();
      if (teacher != null) {
        hasTeacherProfile = true;
        teacherApprovalPending = !teacher.approved;
      }
    }

    var unreadNotificationsCount = 0;
    if (home.availableProfileTypes.contains(UserProfileType.admin) ||
        home.user.isAdmin) {
      unreadNotificationsCount =
          await _remoteDataSource.getUnreadNotificationsCount();
    }

    final displayName = studentProfile?.name ?? teacherProfile?.name;

    return DashboardData(
      user: displayName == null || displayName.isEmpty
          ? home.user
          : home.user.copyWith(name: displayName),
      profileType: home.profileType,
      availableProfileTypes: home.availableProfileTypes,
      profileCompleted: home.profileCompleted,
      studentProfile: studentProfile,
      teacherProfile: teacherProfile,
      hasTeacherProfile: hasTeacherProfile,
      teacherApprovalPending: teacherApprovalPending,
      studentEnrollments: studentEnrollments,
      teacherAssignments: teacherAssignments,
      unreadNotificationsCount: unreadNotificationsCount,
    );
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } catch (_) {
      // Ignora erro do endpoint de logout para garantir que o cliente conclua o signout
    }
    await SessionStore.clear();
  }
}
