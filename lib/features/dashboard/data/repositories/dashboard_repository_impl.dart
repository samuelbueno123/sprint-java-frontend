import '../../../auth/data/datasources/google_identity_datasource.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/student_profile.dart';
import '../../domain/entities/teacher_profile.dart';
import '../../domain/entities/user_profile_type.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(
    this._remoteDataSource,
    this._googleIdentityDataSource,
  );

  final DashboardRemoteDataSource _remoteDataSource;
  final GoogleIdentityDataSource _googleIdentityDataSource;

  @override
  Future<DashboardData> getDashboardData() async {
    final home = await _remoteDataSource.getHomeData();

    StudentProfile? studentProfile;
    TeacherProfile? teacherProfile;

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
    } else if (home.profileType == UserProfileType.teacher) {
      if (home.user.googleId.isNotEmpty) {
        final model = await _remoteDataSource.getTeacherByGoogleId(
          home.user.googleId,
        );
        teacherProfile = model?.toEntity();
      }
      if (teacherProfile == null && home.user.email.isNotEmpty) {
        final model = await _remoteDataSource.getTeacherByEmail(
          home.user.email,
        );
        teacherProfile = model?.toEntity();
      }
    }

    return DashboardData(
      user: home.user,
      profileType: home.profileType,
      profileCompleted: home.profileCompleted,
      studentProfile: studentProfile,
      teacherProfile: teacherProfile,
    );
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } catch (_) {
      // Ignora erro do endpoint de logout para garantir que o cliente conclua o signout
    }
    await _googleIdentityDataSource.signOut();
  }
}
