class TeacherClassAssignment {
  const TeacherClassAssignment({
    required this.id,
    required this.schoolClassName,
    required this.startDate,
    required this.endDate,
    required this.reason,
  });

  final int? id;
  final String schoolClassName;
  final String startDate;
  final String? endDate;
  final String? reason;

  bool get isActive => endDate == null || endDate!.isEmpty;
}
