import '../../../../core/constants/supported_languages.dart';
import '../../domain/entities/teacher_class_assignment.dart';

class TeacherClassAssignmentModel {
  const TeacherClassAssignmentModel({
    required this.id,
    this.schoolClassId,
    required this.schoolClassName,
    this.schoolClassLanguage = '',
    required this.startDate,
    required this.endDate,
    required this.reason,
  });

  factory TeacherClassAssignmentModel.fromJson(Map<String, dynamic> json) {
    final className = json['schoolClassName'] as String? ?? '';
    final rawLanguage =
        json['schoolClassLanguage']?.toString() ??
        json['languageName']?.toString() ??
        '';
    return TeacherClassAssignmentModel(
      id: (json['id'] as num?)?.toInt(),
      schoolClassId: (json['schoolClassId'] as num?)?.toInt(),
      schoolClassName: className,
      schoolClassLanguage: SupportedLanguages.normalizeOrDefault(
        rawLanguage,
        SupportedLanguages.inferFromClassName(className),
      ),
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString(),
      reason: json['reason'] as String?,
    );
  }

  final int? id;
  final int? schoolClassId;
  final String schoolClassName;
  final String schoolClassLanguage;
  final String startDate;
  final String? endDate;
  final String? reason;

  TeacherClassAssignment toEntity() => TeacherClassAssignment(
    id: id,
    schoolClassId: schoolClassId,
    schoolClassName: schoolClassName,
    schoolClassLanguage: schoolClassLanguage,
    startDate: startDate,
    endDate: endDate,
    reason: reason,
  );
}
