import '../../domain/entities/teacher_class_assignment.dart';

class TeacherClassAssignmentModel {
  const TeacherClassAssignmentModel({
    required this.id,
    required this.schoolClassName,
    required this.startDate,
    required this.endDate,
    required this.reason,
  });

  factory TeacherClassAssignmentModel.fromJson(Map<String, dynamic> json) =>
      TeacherClassAssignmentModel(
        id: (json['id'] as num?)?.toInt(),
        schoolClassName: json['schoolClassName'] as String? ?? '',
        startDate: json['startDate']?.toString() ?? '',
        endDate: json['endDate']?.toString(),
        reason: json['reason'] as String?,
      );

  final int? id;
  final String schoolClassName;
  final String startDate;
  final String? endDate;
  final String? reason;

  TeacherClassAssignment toEntity() => TeacherClassAssignment(
    id: id,
    schoolClassName: schoolClassName,
    startDate: startDate,
    endDate: endDate,
    reason: reason,
  );
}
