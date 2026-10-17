enum UserProfileType {
  student('STUDENT', 'Aluno(a)'),
  teacher('TEACHER', 'Professor(a)'),
  admin('ADMIN', 'Administrador(a)'),
  user('USER', 'Usuário');

  const UserProfileType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  String genderLabel(String? gender) {
    final g = gender?.trim().toUpperCase();
    final isFemale = g == 'FEMININO' || g == 'F';
    final isMale = g == 'MASCULINO' || g == 'M';
    switch (this) {
      case UserProfileType.student:
        if (isFemale) return 'Aluna';
        if (isMale) return 'Aluno';
        return 'Aluno';
      case UserProfileType.teacher:
        if (isFemale) return 'Professora';
        if (isMale) return 'Professor';
        return 'Professor';
      case UserProfileType.admin:
        if (isFemale) return 'Administradora';
        if (isMale) return 'Administrador';
        return 'Administrador';
      case UserProfileType.user:
        if (isFemale) return 'Usuária';
        if (isMale) return 'Usuário';
        return 'Usuário';
    }
  }

  static UserProfileType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'STUDENT':
        return UserProfileType.student;
      case 'TEACHER':
        return UserProfileType.teacher;
      case 'ADMIN':
        return UserProfileType.admin;
      default:
        return UserProfileType.user;
    }
  }
}
