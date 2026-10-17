import '../../domain/entities/student_profile.dart';

class StudentModel {
  const StudentModel({
    this.id,
    required this.googleId,
    required this.name,
    required this.email,
    required this.languages,
    this.languageScores = const {},
    this.gender,
    this.institutionId,
    this.institutionName,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    final rawLangs = json['languages'] as List<dynamic>? ?? const [];
    final levels = json['languageLevels'] as Map<String, dynamic>? ?? const {};
    final rawScores =
        json['languageScores'] as Map<String, dynamic>? ?? const {};
    final scores = rawScores.map(
      (language, score) => MapEntry(language, (score as num).toInt()),
    );
    final languages = rawLangs.map((value) {
      final name = value.toString();
      final level = levels[name];
      return level == null ? name : '$name: $level';
    }).toList();

    return StudentModel(
      id: (json['id'] as num?)?.toInt(),
      googleId: json['googleId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      languages: languages,
      languageScores: scores,
      gender: json['gender'] as String?,
      institutionId: (json['institutionId'] as num?)?.toInt(),
      institutionName: json['institutionName'] as String?,
    );
  }

  final int? id;
  final String googleId;
  final String name;
  final String email;
  final List<String> languages;
  final Map<String, int> languageScores;
  final String? gender;
  final int? institutionId;
  final String? institutionName;

  StudentProfile toEntity() => StudentProfile(
    id: id,
    googleId: googleId,
    name: name,
    email: email,
    languages: languages,
    languageScores: languageScores,
    gender: gender,
    institutionId: institutionId,
    institutionName: institutionName,
  );
}
