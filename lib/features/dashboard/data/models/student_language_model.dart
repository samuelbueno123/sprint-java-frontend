import '../../domain/entities/student_language_entity.dart';

class StudentLanguageModel {
  const StudentLanguageModel({
    this.id,
    required this.languageName,
    required this.level,
    required this.score,
  });

  factory StudentLanguageModel.fromJson(Map<String, dynamic> json) {
    return StudentLanguageModel(
      id: (json['id'] as num?)?.toInt(),
      languageName: json['languageName'] as String? ?? '',
      level: json['level'] as String? ?? 'Iniciante',
      score: (json['score'] as num?)?.toInt() ?? 0,
    );
  }

  final int? id;
  final String languageName;
  final String level;
  final int score;

  StudentLanguageEntity toEntity() => StudentLanguageEntity(
    id: id,
    languageName: languageName,
    level: level,
    score: score,
  );
}
