import '../../domain/entities/student_enrollment.dart';

class StudentEnrollmentModel {
  const StudentEnrollmentModel({
    required this.id,
    this.studentId,
    this.schoolClassId,
    required this.schoolClassName,
    required this.enrollmentDate,
    this.cancellationDate,
    required this.status,
  });

  factory StudentEnrollmentModel.fromJson(Map<String, dynamic> json) =>
      StudentEnrollmentModel(
        id: (json['id'] as num?)?.toInt(),
        studentId: (json['studentId'] as num?)?.toInt(),
        schoolClassId: (json['schoolClassId'] as num?)?.toInt(),
        schoolClassName: json['schoolClassName'] as String? ?? '',
        enrollmentDate: json['enrollmentDate']?.toString() ?? '',
        cancellationDate: json['cancellationDate']?.toString(),
        status: json['status']?.toString() ?? '',
      );

  final int? id;
  final int? studentId;
  final int? schoolClassId;
  final String schoolClassName;
  final String enrollmentDate;
  final String? cancellationDate;
  final String status;

  StudentEnrollment toEntity() => StudentEnrollment(
    id: id,
    studentId: studentId,
    schoolClassId: schoolClassId,
    schoolClassName: schoolClassName,
    enrollmentDate: enrollmentDate,
    cancellationDate: cancellationDate,
    status: status,
  );
}
