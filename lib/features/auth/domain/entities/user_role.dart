enum UserRole {
  user,
  student,
  teacher;

  static UserRole fromApiValue(String? value) {
    switch (value?.toUpperCase()) {
      case 'STUDENT':
        return UserRole.student;
      case 'TEACHER':
        return UserRole.teacher;
      default:
        return UserRole.user;
    }
  }
}
