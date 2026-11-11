import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/data/models/backend_auth_session_model.dart';
import 'package:frontend/features/auth/data/models/institution_model.dart';
import 'package:frontend/features/auth/domain/entities/user_role.dart';

void main() {
  group('BackendAuthSessionModel', () {
    test('parses full session payload and converts to entity', () {
      final json = {
        'token': 'jwt.token.value',
        'refreshToken': 'refresh.token.value',
        'profileType': 'STUDENT',
        'user': {
          'id': 42,
          'email': 'student@duolinfo.com',
          'name': 'Carlos Aluno',
          'googleId': 'google-123',
          'profilePicture': 'https://photos.example/carlos.jpg',
        },
      };

      final model = BackendAuthSessionModel.fromJson(json);
      expect(model.accessToken, equals('jwt.token.value'));
      expect(model.refreshToken, equals('refresh.token.value'));
      expect(model.profileType, equals(UserRole.student));
      expect(model.user.id, equals('42'));
      expect(model.user.email, equals('student@duolinfo.com'));
      expect(model.user.name, equals('Carlos Aluno'));
      expect(model.user.googleId, equals('google-123'));
      expect(model.user.photoUrl, equals('https://photos.example/carlos.jpg'));

      final entity = model.toEntity();
      expect(entity.accessToken, equals('jwt.token.value'));
      expect(entity.profileType, equals(UserRole.student));
    });

    test('parses teacher and admin roles accurately', () {
      final teacherJson = {
        'token': 'tok',
        'refreshToken': 'ref',
        'profileType': 'TEACHER',
        'user': {'id': '10', 'email': 'prof@duolinfo.com', 'name': 'Professor'},
      };
      expect(
        BackendAuthSessionModel.fromJson(teacherJson).profileType,
        equals(UserRole.teacher),
      );

      final adminJson = {
        'token': 'tok',
        'refreshToken': 'ref',
        'profileType': 'ADMIN',
        'user': {'id': '1', 'email': 'admin@duolinfo.com', 'name': 'Admin'},
      };
      expect(
        BackendAuthSessionModel.fromJson(adminJson).profileType,
        equals(UserRole.admin),
      );
    });

    test('falls back safely for null or empty fields', () {
      final emptyJson = <String, dynamic>{};
      final model = BackendAuthSessionModel.fromJson(emptyJson);

      expect(model.accessToken, isEmpty);
      expect(model.refreshToken, isEmpty);
      expect(model.profileType, equals(UserRole.user));
      expect(model.user.id, isEmpty);
      expect(model.user.email, isEmpty);
      expect(model.user.photoUrl, isNull);
    });
  });

  group('InstitutionModel', () {
    test('parses json correctly', () {
      final json = {
        'id': 1,
        'name': 'CEFET Nova Iguaçu',
        'code': 'CEFET-NI',
        'city': 'Nova Iguaçu',
        'state': 'RJ',
      };

      final model = InstitutionModel.fromJson(json);
      expect(model.id, equals(1));
      expect(model.name, equals('CEFET Nova Iguaçu'));
      expect(model.code, equals('CEFET-NI'));
      expect(model.city, equals('Nova Iguaçu'));
      expect(model.state, equals('RJ'));
      expect(model.locationString, equals('Nova Iguaçu - RJ'));
      expect(model.toString(), equals('CEFET Nova Iguaçu'));
    });

    test(
      'formats locationString with city only, state only, code fallback or empty',
      () {
        const modelCityOnly = InstitutionModel(
          id: 1,
          name: 'Inst 1',
          city: 'São Paulo',
        );
        expect(modelCityOnly.locationString, equals('São Paulo'));

        const modelCodeOnly = InstitutionModel(
          id: 2,
          name: 'Inst 2',
          code: 'USP-01',
        );
        expect(modelCodeOnly.locationString, equals('USP-01'));

        const modelEmpty = InstitutionModel(id: 3, name: 'Inst 3');
        expect(modelEmpty.locationString, equals(''));
      },
    );

    test('implements value equality based on id', () {
      const instA1 = InstitutionModel(id: 5, name: 'Nome A');
      const instA2 = InstitutionModel(id: 5, name: 'Nome Diferente');
      const instB = InstitutionModel(id: 6, name: 'Nome A');

      expect(instA1 == instA2, isTrue);
      expect(instA1 == instB, isFalse);
      expect(instA1.hashCode, equals(instA2.hashCode));
    });
  });
}
