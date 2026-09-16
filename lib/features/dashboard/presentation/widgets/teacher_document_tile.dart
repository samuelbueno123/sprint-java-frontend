import 'package:flutter/material.dart';

import '../../domain/entities/teacher_document_entity.dart';

class TeacherDocumentTile extends StatelessWidget {
  const TeacherDocumentTile({super.key, required this.document});

  final TeacherDocumentEntity document;

  IconData _getIconForType(String contentType) {
    if (contentType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (contentType.contains('word') || contentType.contains('msword')) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    const teacherBlue = Color(0xFF1CB0F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: teacherBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconForType(document.contentType),
              color: teacherBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  document.formattedFileSize,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_user_rounded,
            color: Colors.green,
            size: 18,
          ),
        ],
      ),
    );
  }
}
