import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/data/models/student_model.dart';

void main() {
  group('StudentModel', () {
    test('parses the backend student DTO languages', () {
      final json = {
        'id': 1,
        'googleId': '12345',
        'name': 'Maria Aluna',
        'email': 'student@duolinfo.com',
        'languages': ['Inglês', 'Espanhol'],
      };

      final model = StudentModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.id, equals(1));
      expect(entity.languages, equals(['Inglês', 'Espanhol']));
    });
  });
}
