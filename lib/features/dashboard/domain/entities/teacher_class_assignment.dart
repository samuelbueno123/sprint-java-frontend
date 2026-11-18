import '../../../../core/constants/supported_languages.dart';

class TeacherClassAssignment {
  const TeacherClassAssignment({
    required this.id,
    this.schoolClassId,
    required this.schoolClassName,
    this.schoolClassLanguage = '',
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.schoolClassPictureUrl,
  });

  final int? id;
  final int? schoolClassId;
  final String schoolClassName;
  final String schoolClassLanguage;
  final String startDate;
  final String? endDate;
  final String? reason;
  final String? schoolClassPictureUrl;

  String get resolvedLanguage => SupportedLanguages.normalizeOrDefault(
    schoolClassLanguage,
    SupportedLanguages.inferFromClassName(schoolClassName),
  );

  bool get isActive => endDate == null || endDate!.isEmpty;
}
