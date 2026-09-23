import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/data/models/teacher_model.dart';

void main() {
  group('TeacherModel', () {
    test('parses the backend teacher DTO fields', () {
      final json = {
        'id': 2,
        'googleId': '67890',
        'name': 'Prof. Carlos',
        'email': 'teacher@duolinfo.com',
        'institutionId': 7,
        'taughtLanguages': ['Inglês', 'Francês'],
        'specializationAreas': ['Linguística'],
        'bibliography': 'Doutor em Letras',
      };

      final model = TeacherModel.fromJson(json);
      final entity = model.toEntity(institutionName: 'Universidade Federal');

      expect(entity.id, equals(2));
      expect(entity.institution, equals('Universidade Federal'));
      expect(entity.institutionId, equals(7));
      expect(entity.taughtLanguages, contains('Inglês'));
      expect(entity.specializationAreas, contains('Linguística'));
      expect(entity.bibliography, equals('Doutor em Letras'));
    });
  });
}
