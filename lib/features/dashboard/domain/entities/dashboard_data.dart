import 'student_profile.dart';
import 'student_enrollment.dart';
import 'teacher_class_assignment.dart';
import 'teacher_profile.dart';
import 'user_profile_type.dart';

class DashboardUser {
  const DashboardUser({
    this.id = '',
    required this.googleId,
    required this.email,
    required this.name,
    this.picture,
  });

  final String id;
  final String googleId;
  final String email;
  final String name;
  final String? picture;

  DashboardUser copyWith({
    String? id,
    String? name,
    String? email,
    String? picture,
  }) => DashboardUser(
    id: id ?? this.id,
    googleId: googleId,
    email: email ?? this.email,
    name: name ?? this.name,
    picture: picture ?? this.picture,
  );
}

class DashboardData {
  const DashboardData({
    required this.user,
    required this.profileType,
    this.availableProfileTypes = const [],
    required this.profileCompleted,
    this.studentProfile,
    this.teacherProfile,
    this.hasTeacherProfile = false,
    this.teacherApprovalPending = false,
    this.studentEnrollments = const [],
    this.teacherAssignments = const [],
  });

  final DashboardUser user;
  final UserProfileType profileType;
  final List<UserProfileType> availableProfileTypes;
  final bool profileCompleted;
  final StudentProfile? studentProfile;
  final TeacherProfile? teacherProfile;
  final bool hasTeacherProfile;
  final bool teacherApprovalPending;
  final List<StudentEnrollment> studentEnrollments;
  final List<TeacherClassAssignment> teacherAssignments;

  DashboardData copyWith({UserProfileType? profileType}) => DashboardData(
    user: user,
    profileType: profileType ?? this.profileType,
    availableProfileTypes: availableProfileTypes,
    profileCompleted: profileCompleted,
    studentProfile: studentProfile,
    teacherProfile: teacherProfile,
    hasTeacherProfile: hasTeacherProfile,
    teacherApprovalPending: teacherApprovalPending,
    studentEnrollments: studentEnrollments,
    teacherAssignments: teacherAssignments,
  );
}
