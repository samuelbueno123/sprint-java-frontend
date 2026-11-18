import '../../../../core/constants/supported_languages.dart';
import '../../domain/entities/student_enrollment.dart';

class StudentEnrollmentModel {
  const StudentEnrollmentModel({
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

  factory StudentEnrollmentModel.fromJson(Map<String, dynamic> json) {
    final className = json['schoolClassName'] as String? ?? '';
    final rawLanguage =
        json['schoolClassLanguage']?.toString() ??
        json['languageName']?.toString() ??
        '';
    return StudentEnrollmentModel(
      id: (json['id'] as num?)?.toInt(),
      studentId: (json['studentId'] as num?)?.toInt(),
      schoolClassId: (json['schoolClassId'] as num?)?.toInt(),
      schoolClassName: className,
      schoolClassLanguage: SupportedLanguages.normalizeOrDefault(
        rawLanguage,
        SupportedLanguages.inferFromClassName(className),
      ),
      enrollmentDate: json['enrollmentDate']?.toString() ?? '',
      cancellationDate: json['cancellationDate']?.toString(),
      status: json['status']?.toString() ?? '',
      schoolClassPictureUrl: json['schoolClassPictureUrl']?.toString(),
    );
  }

  final int? id;
  final int? studentId;
  final int? schoolClassId;
  final String schoolClassName;
  final String schoolClassLanguage;
  final String enrollmentDate;
  final String? cancellationDate;
  final String status;
  final String? schoolClassPictureUrl;

  StudentEnrollment toEntity() => StudentEnrollment(
    id: id,
    studentId: studentId,
    schoolClassId: schoolClassId,
    schoolClassName: schoolClassName,
    schoolClassLanguage: schoolClassLanguage,
    enrollmentDate: enrollmentDate,
    cancellationDate: cancellationDate,
    status: status,
    schoolClassPictureUrl: schoolClassPictureUrl,
  );
}
