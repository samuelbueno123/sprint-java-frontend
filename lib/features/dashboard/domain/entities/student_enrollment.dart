class StudentEnrollment {
  const StudentEnrollment({
    required this.id,
    required this.schoolClassName,
    required this.enrollmentDate,
    required this.status,
  });

  final int? id;
  final String schoolClassName;
  final String enrollmentDate;
  final String status;
}
