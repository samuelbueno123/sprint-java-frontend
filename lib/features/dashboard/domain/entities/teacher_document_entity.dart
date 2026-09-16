class TeacherDocumentEntity {
  const TeacherDocumentEntity({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.fileSize,
  });

  final int? id;
  final String fileName;
  final String contentType;
  final int fileSize;

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
