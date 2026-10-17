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
    this.gender,
    this.institutionAdmin = false,
    this.primaryInstitutionAdmin = false,
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
  final String? gender;
  final bool institutionAdmin;
  final bool primaryInstitutionAdmin;

  bool get isFemale =>
      gender?.trim().toUpperCase() == 'FEMININO' ||
      gender?.trim().toUpperCase() == 'F';
}
