enum UserRole {
  student('STUDENT', 'aluno(a)'),
  teacher('TEACHER', 'professor(a)');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
