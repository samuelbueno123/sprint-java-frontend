import '../../domain/entities/student_enrollment.dart';

class StudentEnrollmentModel {
  const StudentEnrollmentModel({
    required this.id,
    required this.schoolClassName,
    required this.enrollmentDate,
    required this.status,
  });

  factory StudentEnrollmentModel.fromJson(Map<String, dynamic> json) =>
      StudentEnrollmentModel(
        id: (json['id'] as num?)?.toInt(),
        schoolClassName: json['schoolClassName'] as String? ?? '',
        enrollmentDate: json['enrollmentDate']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
      );

  final int? id;
  final String schoolClassName;
  final String enrollmentDate;
  final String status;

  StudentEnrollment toEntity() => StudentEnrollment(
    id: id,
    schoolClassName: schoolClassName,
    enrollmentDate: enrollmentDate,
    status: status,
  );
}
