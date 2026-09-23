class StudentProfile {
  const StudentProfile({
    this.id,
    required this.googleId,
    required this.name,
    required this.email,
    required this.languages,
  });

  final int? id;
  final String googleId;
  final String name;
  final String email;
  final List<String> languages;
}
