class StudentEnrollment {
  const StudentEnrollment({
    required this.id,
    this.studentId,
    required this.schoolClassName,
    required this.enrollmentDate,
    required this.status,
  });

  final int? id;
  final int? studentId;
  final String schoolClassName;
  final String enrollmentDate;
  final String status;
}
