import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/data/models/student_enrollment_model.dart';
import 'package:frontend/features/dashboard/data/models/student_language_model.dart';
import 'package:frontend/features/dashboard/data/models/teacher_class_assignment_model.dart';
import 'package:frontend/features/dashboard/data/models/teacher_document_model.dart';

void main() {
  group('StudentEnrollmentModel', () {
    test('parses active enrollment json and converts to entity', () {
      final json = {
        'id': 101,
        'studentId': 20,
        'schoolClassId': 5,
        'schoolClassName': 'Turma A1 - Inglês',
        'enrollmentDate': '2026-02-15',
        'cancellationDate': null,
        'status': 'ACTIVE',
      };

      final model = StudentEnrollmentModel.fromJson(json);
      expect(model.id, equals(101));
      expect(model.studentId, equals(20));
      expect(model.schoolClassId, equals(5));
      expect(model.schoolClassName, equals('Turma A1 - Inglês'));
      expect(model.enrollmentDate, equals('2026-02-15'));
      expect(model.cancellationDate, isNull);
      expect(model.status, equals('ACTIVE'));

      final entity = model.toEntity();
      expect(entity.id, equals(101));
      expect(entity.schoolClassName, equals('Turma A1 - Inglês'));
      expect(entity.status, equals('ACTIVE'));
    });

    test('parses cancelled enrollment with cancellationDate', () {
      final json = {
        'id': 102,
        'studentId': 20,
        'schoolClassId': 5,
        'schoolClassName': 'Turma A1',
        'enrollmentDate': '2026-01-10',
        'cancellationDate': '2026-03-01',
        'status': 'CANCELLED',
      };

      final model = StudentEnrollmentModel.fromJson(json);
      expect(model.status, equals('CANCELLED'));
      expect(model.cancellationDate, equals('2026-03-01'));
    });
  });

  group('StudentLanguageModel', () {
    test('parses full language details and maps to entity', () {
      final json = {
        'id': 7,
        'languageName': 'Francês',
        'level': 'Intermediário',
        'score': 450,
      };

      final model = StudentLanguageModel.fromJson(json);
      expect(model.id, equals(7));
      expect(model.languageName, equals('Francês'));
      expect(model.level, equals('Intermediário'));
      expect(model.score, equals(450));

      final entity = model.toEntity();
      expect(entity.id, equals(7));
      expect(entity.languageName, equals('Francês'));
      expect(entity.level, equals('Intermediário'));
      expect(entity.score, equals(450));
    });

    test('applies sensible defaults when level or score are missing', () {
      final json = {'id': 8, 'languageName': 'Alemão'};

      final model = StudentLanguageModel.fromJson(json);
      expect(model.level, equals('Iniciante'));
      expect(model.score, equals(0));
    });
  });

  group('TeacherClassAssignmentModel', () {
    test('parses assignment json and maps to entity', () {
      final json = {
        'id': 44,
        'schoolClassId': 12,
        'schoolClassName': 'Turma Espanhol B1',
        'startDate': '2026-02-01',
        'endDate': '2026-06-30',
        'reason': 'Professor titular',
      };

      final model = TeacherClassAssignmentModel.fromJson(json);
      expect(model.id, equals(44));
      expect(model.schoolClassId, equals(12));
      expect(model.schoolClassName, equals('Turma Espanhol B1'));
      expect(model.startDate, equals('2026-02-01'));
      expect(model.endDate, equals('2026-06-30'));
      expect(model.reason, equals('Professor titular'));

      final entity = model.toEntity();
      expect(entity.id, equals(44));
      expect(entity.schoolClassName, equals('Turma Espanhol B1'));
      expect(entity.reason, equals('Professor titular'));
    });
  });

  group('TeacherDocumentModel', () {
    test('parses document metadata and maps to entity', () {
      final json = {
        'id': 19,
        'fileName': 'diploma_licenciatura.pdf',
        'contentType': 'application/pdf',
        'fileSize': 1048576,
      };

      final model = TeacherDocumentModel.fromJson(json);
      expect(model.id, equals(19));
      expect(model.fileName, equals('diploma_licenciatura.pdf'));
      expect(model.contentType, equals('application/pdf'));
      expect(model.fileSize, equals(1048576));

      final entity = model.toEntity();
      expect(entity.id, equals(19));
      expect(entity.fileName, equals('diploma_licenciatura.pdf'));
      expect(entity.fileSize, equals(1048576));
    });

    test('defaults contentType to application/octet-stream if omitted', () {
      final json = {'id': 20, 'fileName': 'arquivo_desconhecido'};

      final model = TeacherDocumentModel.fromJson(json);
      expect(model.contentType, equals('application/octet-stream'));
      expect(model.fileSize, equals(0));
    });
  });
}
