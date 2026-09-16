import 'teacher_document_entity.dart';

class TeacherProfile {
  const TeacherProfile({
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

  final int? id;
  final String googleId;
  final String name;
  final String email;
  final String? profilePicture;
  final String institution;
  final List<String> taughtLanguages;
  final List<String> specializationAreas;
  final String? bibliography;
  final List<TeacherDocumentEntity> documents;
}
