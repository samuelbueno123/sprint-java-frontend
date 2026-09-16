import 'student_profile.dart';
import 'teacher_profile.dart';
import 'user_profile_type.dart';

class DashboardUser {
  const DashboardUser({
    required this.googleId,
    required this.email,
    required this.name,
    this.picture,
  });

  final String googleId;
  final String email;
  final String name;
  final String? picture;
}

class DashboardData {
  const DashboardData({
    required this.user,
    required this.profileType,
    required this.profileCompleted,
    this.studentProfile,
    this.teacherProfile,
  });

  final DashboardUser user;
  final UserProfileType profileType;
  final bool profileCompleted;
  final StudentProfile? studentProfile;
  final TeacherProfile? teacherProfile;
}
