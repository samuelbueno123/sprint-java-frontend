import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/data/models/home_response_model.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';

void main() {
  group('HomeResponseModel', () {
    test('should correctly parse STUDENT response from json', () {
      final json = {
        'success': true,
        'user': {
          'googleId': '12345',
          'email': 'student@duolinfo.com',
          'name': 'Maria Aluna',
          'picture': 'https://example.com/pic.jpg',
        },
        'profileType': 'STUDENT',
        'profileCompleted': true,
      };

      final model = HomeResponseModel.fromJson(json);

      expect(model.success, isTrue);
      expect(model.user.googleId, equals('12345'));
      expect(model.user.email, equals('student@duolinfo.com'));
      expect(model.user.name, equals('Maria Aluna'));
      expect(model.profileType, equals(UserProfileType.student));
      expect(model.profileCompleted, isTrue);
    });

    test('should correctly parse TEACHER response from json', () {
      final json = {
        'success': true,
        'user': {
          'googleId': '67890',
          'email': 'teacher@duolinfo.com',
          'name': 'Prof. Carlos',
        },
        'profileType': 'TEACHER',
        'profileCompleted': true,
      };

      final model = HomeResponseModel.fromJson(json);

      expect(model.profileType, equals(UserProfileType.teacher));
      expect(model.user.name, equals('Prof. Carlos'));
    });

    test('should fallback to USER when profileType is unrecognized', () {
      final json = {
        'success': true,
        'user': {
          'googleId': '999',
          'email': 'user@duolinfo.com',
          'name': 'User',
        },
        'profileType': 'UNKNOWN',
        'profileCompleted': false,
      };

      final model = HomeResponseModel.fromJson(json);

      expect(model.profileType, equals(UserProfileType.user));
    });
  });
}
