class StudentProfile {
  const StudentProfile({
    this.id,
    required this.googleId,
    required this.name,
    required this.email,
    required this.languages,
    this.languageScores = const {},
    this.gender,
    this.institutionId,
    this.institutionName,
    this.institutionPictureUrl,
  });

  final int? id;
  final String googleId;
  final String name;
  final String email;
  final List<String> languages;
  final Map<String, int> languageScores;
  final String? gender;
  final int? institutionId;
  final String? institutionName;
  final String? institutionPictureUrl;

  bool get isFemale =>
      gender?.trim().toUpperCase() == 'FEMININO' ||
      gender?.trim().toUpperCase() == 'F';
}
