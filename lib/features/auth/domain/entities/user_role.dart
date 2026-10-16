enum UserRole {
  user,
  student,
  teacher,
  admin;

  static UserRole fromApiValue(String? value) {
    switch (value?.toUpperCase()) {
      case 'STUDENT':
        return UserRole.student;
      case 'TEACHER':
        return UserRole.teacher;
      case 'ADMIN':
        return UserRole.admin;
      default:
        return UserRole.user;
    }
  }
}
