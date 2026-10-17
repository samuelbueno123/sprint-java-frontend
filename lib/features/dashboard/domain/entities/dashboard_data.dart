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
    this.gender,
    this.isAdmin = false,
    this.isSuperAdmin = false,
  });

  final String id;
  final String googleId;
  final String email;
  final String name;
  final String? picture;
  final String? gender;
  final bool isAdmin;
  final bool isSuperAdmin;

  bool get isFemale =>
      gender?.trim().toUpperCase() == 'FEMININO' ||
      gender?.trim().toUpperCase() == 'F';

  DashboardUser copyWith({
    String? id,
    String? name,
    String? email,
    String? picture,
    String? gender,
    bool? isAdmin,
    bool? isSuperAdmin,
  }) => DashboardUser(
    id: id ?? this.id,
    googleId: googleId,
    email: email ?? this.email,
    name: name ?? this.name,
    picture: picture ?? this.picture,
    gender: gender ?? this.gender,
    isAdmin: isAdmin ?? this.isAdmin,
    isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
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
    this.unreadNotificationsCount = 0,
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
  final int unreadNotificationsCount;

  String? get effectiveGender =>
      user.gender ?? studentProfile?.gender ?? teacherProfile?.gender;

  bool get isFemale {
    final g = effectiveGender?.trim().toUpperCase();
    return g == 'FEMININO' || g == 'F';
  }

  String get welcomePrefix => isFemale ? 'Bem-vinda' : 'Bem-vindo';

  String get roleLabel => profileType.genderLabel(effectiveGender);

  DashboardData copyWith({
    UserProfileType? profileType,
    int? unreadNotificationsCount,
  }) => DashboardData(
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
    unreadNotificationsCount:
        unreadNotificationsCount ?? this.unreadNotificationsCount,
  );
}
