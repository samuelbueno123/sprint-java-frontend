import '../../domain/entities/teacher_profile.dart';
import 'teacher_document_model.dart';

class TeacherModel {
  const TeacherModel({
    this.id,
    required this.googleId,
    required this.name,
    required this.email,
    this.profilePicture,
    required this.institution,
    required this.taughtLanguages,
    required this.specializationAreas,
    this.bibliography,
    required this.documents,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    final rawDocs = json['documents'] as List<dynamic>? ?? const [];
    final docs = rawDocs
        .whereType<Map<String, dynamic>>()
        .map(TeacherDocumentModel.fromJson)
        .toList();

    final rawTaught = json['taughtLanguages'] as List<dynamic>? ?? const [];
    final taughtLangs = rawTaught.map((e) => e.toString()).toList();

    final rawSpecs = json['specializationAreas'] as List<dynamic>? ?? const [];
    final specs = rawSpecs.map((e) => e.toString()).toList();

    return TeacherModel(
      id: (json['id'] as num?)?.toInt(),
      googleId: json['googleId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePicture: json['profilePicture'] as String?,
      institution: json['institution'] as String? ?? '',
      taughtLanguages: taughtLangs,
      specializationAreas: specs,
      bibliography: json['bibliography'] as String?,
      documents: docs,
    );
  }

  final int? id;
  final String googleId;
  final String name;
  final String email;
  final String? profilePicture;
  final String institution;
  final List<String> taughtLanguages;
  final List<String> specializationAreas;
  final String? bibliography;
  final List<TeacherDocumentModel> documents;

  TeacherProfile toEntity() => TeacherProfile(
    id: id,
    googleId: googleId,
    name: name,
    email: email,
    profilePicture: profilePicture,
    institution: institution,
    taughtLanguages: taughtLanguages,
    specializationAreas: specializationAreas,
    bibliography: bibliography,
    documents: documents.map((d) => d.toEntity()).toList(),
  );
}
