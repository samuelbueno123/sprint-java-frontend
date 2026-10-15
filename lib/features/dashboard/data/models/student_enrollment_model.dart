import '../../domain/entities/student_enrollment.dart';

class StudentEnrollmentModel {
  const StudentEnrollmentModel({
    required this.id,
    this.studentId,
    required this.schoolClassName,
    required this.enrollmentDate,
    required this.status,
  });

  factory StudentEnrollmentModel.fromJson(Map<String, dynamic> json) =>
      StudentEnrollmentModel(
        id: (json['id'] as num?)?.toInt(),
        studentId: (json['studentId'] as num?)?.toInt(),
        schoolClassName: json['schoolClassName'] as String? ?? '',
        enrollmentDate: json['enrollmentDate']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
      );

  final int? id;
  final int? studentId;
  final String schoolClassName;
  final String enrollmentDate;
  final String status;

  StudentEnrollment toEntity() => StudentEnrollment(
    id: id,
    studentId: studentId,
    schoolClassName: schoolClassName,
    enrollmentDate: enrollmentDate,
    status: status,
  );
}
