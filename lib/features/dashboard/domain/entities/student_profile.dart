class StudentProfile {
  const StudentProfile({
    this.id,
    required this.googleId,
    required this.name,
    required this.email,
    required this.languages,
    this.languageScores = const {},
  });

  final int? id;
  final String googleId;
  final String name;
  final String email;
  final List<String> languages;
  final Map<String, int> languageScores;
}
