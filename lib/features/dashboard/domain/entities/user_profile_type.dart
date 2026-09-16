enum UserProfileType {
  student('STUDENT', 'Aluno(a)'),
  teacher('TEACHER', 'Professor(a)'),
  user('USER', 'Usuário');

  const UserProfileType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static UserProfileType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'STUDENT':
        return UserProfileType.student;
      case 'TEACHER':
        return UserProfileType.teacher;
      default:
        return UserProfileType.user;
    }
  }
}
