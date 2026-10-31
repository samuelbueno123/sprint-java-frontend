class StudentEnrollment {
  const StudentEnrollment({
    required this.id,
    this.studentId,
    this.schoolClassId,
    required this.schoolClassName,
    required this.enrollmentDate,
    this.cancellationDate,
    required this.status,
  });

  final int? id;
  final int? studentId;
  final int? schoolClassId;
  final String schoolClassName;
  final String enrollmentDate;
  final String? cancellationDate;
  final String status;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}
