import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/data/datasources/auth_remote_datasource.dart';

class MockAdapter implements HttpClientAdapter {
  MockAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late AuthRemoteDataSource dataSource;
  late RequestOptions capturedOptions;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
    dataSource = AuthRemoteDataSource(dio);
  });

  group('AuthRemoteDataSource', () {
    test(
      'exchangeGoogleIdToken posts credential payload and parses session',
      () async {
        dio.httpClientAdapter = MockAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({
              'token': 'google-access-jwt',
              'refreshToken': 'google-refresh-jwt',
              'profileType': 'STUDENT',
              'user': {
                'id': 1,
                'email': 'student@duolinfo.com',
                'name': 'Estudante Google',
                'googleId': 'gid-999',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final result = await dataSource.exchangeGoogleIdToken(
          idToken: 'raw-id-token',
        );

        expect(capturedOptions.data, equals({'credential': 'raw-id-token'}));
        expect(result.accessToken, equals('google-access-jwt'));
        expect(result.user.name, equals('Estudante Google'));
      },
    );

    test('signInWithPassword sends trimmed email and password', () async {
      dio.httpClientAdapter = MockAdapter((options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({
            'token': 'pass-access-jwt',
            'refreshToken': 'pass-refresh-jwt',
            'profileType': 'TEACHER',
            'user': {
              'id': 2,
              'email': 'teacher@duolinfo.com',
              'name': 'Professor Silva',
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final result = await dataSource.signInWithPassword(
        email: '  teacher@duolinfo.com  ',
        password: 'securePassword123',
      );

      expect(
        capturedOptions.data,
        equals({
          'email': 'teacher@duolinfo.com',
          'password': 'securePassword123',
        }),
      );
      expect(result.accessToken, equals('pass-access-jwt'));
    });

    test(
      'fetchInstitutions queries all institutions when query is null',
      () async {
        dio.httpClientAdapter = MockAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode([
              {'id': 1, 'name': 'CEFET-RJ', 'city': 'Nova Iguaçu'},
              {'id': 2, 'name': 'UFRJ', 'city': 'Rio de Janeiro'},
            ]),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final result = await dataSource.fetchInstitutions();

        expect(result.length, equals(2));
        expect(result[0].name, equals('CEFET-RJ'));
        expect(result[1].name, equals('UFRJ'));
      },
    );

    test('fetchInstitutions filters by query when provided', () async {
      dio.httpClientAdapter = MockAdapter((options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode([
            {'id': 1, 'name': 'CEFET-RJ', 'city': 'Nova Iguaçu'},
          ]),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final result = await dataSource.fetchInstitutions('cefet');

      expect(capturedOptions.path, contains('cefet'));
      expect(result.length, equals(1));
      expect(result.first.name, equals('CEFET-RJ'));
    });

    test('fetchLanguages returns list of string languages', () async {
      dio.httpClientAdapter = MockAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode(['Inglês', 'Espanhol', 'Francês']),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final result = await dataSource.fetchLanguages();
      expect(result, equals(['Inglês', 'Espanhol', 'Francês']));
    });

    test(
      'fetchProficiencyLevels returns list of proficiency strings',
      () async {
        dio.httpClientAdapter = MockAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode(['Iniciante', 'Intermediário', 'Avançado']),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final result = await dataSource.fetchProficiencyLevels();
        expect(result, equals(['Iniciante', 'Intermediário', 'Avançado']));
      },
    );

    test(
      'createStudent posts payload with trimmed fields and languages list',
      () async {
        dio.httpClientAdapter = MockAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({'id': 10}),
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        await dataSource.createStudent(
          name: ' Novo Aluno ',
          email: ' NOVO@DUOLINFO.COM ',
          password: 'pass',
          googleId: '',
          languages: [
            {'languageName': 'Inglês', 'level': 'Iniciante'},
          ],
          institutionId: 1,
        );

        final data = capturedOptions.data as Map<String, dynamic>;
        expect(data['name'], equals('Novo Aluno'));
        expect(data['email'], equals('novo@duolinfo.com'));
        expect(data['googleId'], isNull);
        expect(data['institutionId'], equals(1));
      },
    );

    test(
      'createTeacher posts payload with taught languages and bibliography',
      () async {
        dio.httpClientAdapter = MockAdapter((options) async {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({'id': 11}),
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        await dataSource.createTeacher(
          name: ' Novo Professor ',
          email: ' PROF@DUOLINFO.COM ',
          password: 'pass',
          googleId: 'g-prof',
          institutionId: 2,
          taughtLanguages: ['Inglês'],
          specializationAreas: ['Linguística Aplicada'],
          bibliography: ' Mestre em Letras ',
        );

        final data = capturedOptions.data as Map<String, dynamic>;
        expect(data['name'], equals('Novo Professor'));
        expect(data['email'], equals('prof@duolinfo.com'));
        expect(data['googleId'], equals('g-prof'));
        expect(data['bibliography'], equals('Mestre em Letras'));
        expect(data['taughtLanguages'], equals(['Inglês']));
      },
    );
  });
}
