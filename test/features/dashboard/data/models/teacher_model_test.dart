import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/data/models/teacher_model.dart';

void main() {
  group('TeacherModel', () {
    test('should parse teacher json with documents correctly', () {
      final json = {
        'id': 2,
        'googleId': '67890',
        'name': 'Prof. Carlos',
        'email': 'teacher@duolinfo.com',
        'institution': 'Universidade Federal',
        'taughtLanguages': ['Inglês', 'Francês'],
        'specializationAreas': ['Linguística'],
        'bibliography': 'Doutor em Letras',
        'documents': [
          {
            'id': 100,
            'fileName': 'Diploma.pdf',
            'contentType': 'application/pdf',
            'fileSize': 1048576,
          },
        ],
      };

      final model = TeacherModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.institution, equals('Universidade Federal'));
      expect(entity.taughtLanguages, contains('Inglês'));
      expect(entity.specializationAreas, contains('Linguística'));
      expect(entity.documents.length, equals(1));
      expect(entity.documents[0].formattedFileSize, equals('1.0 MB'));
    });
  });
}
