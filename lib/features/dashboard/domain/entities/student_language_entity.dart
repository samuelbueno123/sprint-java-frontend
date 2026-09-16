class StudentLanguageEntity {
  const StudentLanguageEntity({
    required this.id,
    required this.languageName,
    required this.level,
    required this.score,
  });

  final int? id;
  final String languageName;
  final String level;
  final int score;
}
