import '../../domain/entities/teacher_document_entity.dart';

class TeacherDocumentModel {
  const TeacherDocumentModel({
    this.id,
    required this.fileName,
    required this.contentType,
    required this.fileSize,
  });

  factory TeacherDocumentModel.fromJson(Map<String, dynamic> json) {
    return TeacherDocumentModel(
      id: (json['id'] as num?)?.toInt(),
      fileName: json['fileName'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
    );
  }

  final int? id;
  final String fileName;
  final String contentType;
  final int fileSize;

  TeacherDocumentEntity toEntity() => TeacherDocumentEntity(
    id: id,
    fileName: fileName,
    contentType: contentType,
    fileSize: fileSize,
  );
}
