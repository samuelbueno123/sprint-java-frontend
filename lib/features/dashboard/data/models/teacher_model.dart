import '../../domain/entities/teacher_profile.dart';

class TeacherModel {
  const TeacherModel({
    this.id,
    required this.googleId,
    required this.name,
    required this.email,
    this.institutionId,
    required this.institution,
    required this.taughtLanguages,
    required this.specializationAreas,
    this.bibliography,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    final rawTaught = json['taughtLanguages'] as List<dynamic>? ?? const [];
    final taughtLangs = rawTaught.map((e) => e.toString()).toList();

    final rawSpecs = json['specializationAreas'] as List<dynamic>? ?? const [];
    final specs = rawSpecs.map((e) => e.toString()).toList();

    return TeacherModel(
      id: (json['id'] as num?)?.toInt(),
      googleId: json['googleId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      institutionId: (json['institutionId'] as num?)?.toInt(),
      institution:
          json['institution'] as String? ??
          (json['institutionId'] == null
              ? ''
              : 'Instituição #${json['institutionId']}'),
      taughtLanguages: taughtLangs,
      specializationAreas: specs,
      bibliography: json['bibliography'] as String?,
    );
  }

  final int? id;
  final String googleId;
  final String name;
  final String email;
  final int? institutionId;
  final String institution;
  final List<String> taughtLanguages;
  final List<String> specializationAreas;
  final String? bibliography;

  TeacherProfile toEntity({String? institutionName}) => TeacherProfile(
    id: id,
    googleId: googleId,
    name: name,
    email: email,
    institution: institutionName ?? institution,
    institutionId: institutionId,
    taughtLanguages: taughtLanguages,
    specializationAreas: specializationAreas,
    bibliography: bibliography,
  );
}
