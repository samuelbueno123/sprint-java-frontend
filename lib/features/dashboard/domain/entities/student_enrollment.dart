import '../../../../core/constants/supported_languages.dart';

class StudentEnrollment {
  const StudentEnrollment({
    required this.id,
    this.studentId,
    this.schoolClassId,
    required this.schoolClassName,
    this.schoolClassLanguage = '',
    required this.enrollmentDate,
    this.cancellationDate,
    required this.status,
    this.schoolClassPictureUrl,
  });

  final int? id;
  final int? studentId;
  final int? schoolClassId;
  final String schoolClassName;
  final String schoolClassLanguage;
  final String enrollmentDate;
  final String? cancellationDate;
  final String status;
  final String? schoolClassPictureUrl;

  String get resolvedLanguage => SupportedLanguages.normalizeOrDefault(
    schoolClassLanguage,
    SupportedLanguages.inferFromClassName(schoolClassName),
  );

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}
