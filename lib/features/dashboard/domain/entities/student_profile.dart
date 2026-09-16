import 'student_language_entity.dart';

class StudentProfile {
  const StudentProfile({
    this.id,
    required this.googleId,
    required this.name,
    required this.email,
    this.profilePicture,
    required this.languages,
  });

  final int? id;
  final String googleId;
  final String name;
  final String email;
  final String? profilePicture;
  final List<StudentLanguageEntity> languages;

  int get totalScore => languages.fold(0, (sum, lang) => sum + lang.score);
}
