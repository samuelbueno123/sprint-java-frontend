import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/data/models/student_model.dart';

void main() {
  group('StudentModel', () {
    test('should parse student json with languages correctly', () {
      final json = {
        'id': 1,
        'googleId': '12345',
        'name': 'Maria Aluna',
        'email': 'student@duolinfo.com',
        'profilePicture': 'https://example.com/pic.jpg',
        'languages': [
          {'id': 10, 'languageName': 'Inglês', 'level': 'B2', 'score': 1500},
          {'id': 11, 'languageName': 'Espanhol', 'level': 'A1', 'score': 350},
        ],
      };

      final model = StudentModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.id, equals(1));
      expect(entity.languages.length, equals(2));
      expect(entity.languages[0].languageName, equals('Inglês'));
      expect(entity.languages[0].score, equals(1500));
      expect(entity.totalScore, equals(1850));
    });
  });
}
