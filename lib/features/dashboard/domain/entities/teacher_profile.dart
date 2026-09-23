class TeacherProfile {
  const TeacherProfile({
    this.id,
    required this.googleId,
    required this.name,
    required this.email,
    required this.institution,
    this.institutionId,
    required this.taughtLanguages,
    required this.specializationAreas,
    this.bibliography,
  });

  final int? id;
  final String googleId;
  final String name;
  final String email;
  final String institution;
  final int? institutionId;
  final List<String> taughtLanguages;
  final List<String> specializationAreas;
  final String? bibliography;
}
