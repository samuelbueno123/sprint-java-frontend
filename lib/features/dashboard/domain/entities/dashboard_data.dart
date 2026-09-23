import 'student_profile.dart';
import 'student_enrollment.dart';
import 'teacher_class_assignment.dart';
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

  DashboardUser copyWith({String? name}) => DashboardUser(
    googleId: googleId,
    email: email,
    name: name ?? this.name,
    picture: picture,
  );
}

class DashboardData {
  const DashboardData({
    required this.user,
    required this.profileType,
    required this.profileCompleted,
    this.studentProfile,
    this.teacherProfile,
    this.studentEnrollments = const [],
    this.teacherAssignments = const [],
  });

  final DashboardUser user;
  final UserProfileType profileType;
  final bool profileCompleted;
  final StudentProfile? studentProfile;
  final TeacherProfile? teacherProfile;
  final List<StudentEnrollment> studentEnrollments;
  final List<TeacherClassAssignment> teacherAssignments;
}
