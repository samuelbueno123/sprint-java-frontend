import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/core/network/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.clear();
  });

  tearDown(() async {
    await SessionStore.clear();
  });

  group('ApiClient', () {
    test(
      'attaches Authorization header when session token is active',
      () async {
        await SessionStore.setSession(
          accessToken: 'valid-jwt-token',
          refreshToken: 'valid-refresh-token',
        );

        final client = ApiClient();
        RequestOptions? interceptedOptions;

        client.dio.httpClientAdapter = MockAdapter((options) async {
          interceptedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({'status': 'ok'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final response = await client.dio.get<Map<String, dynamic>>(
          '/api/test',
        );

        expect(response.statusCode, equals(200));
        expect(interceptedOptions, isNotNull);
        expect(
          interceptedOptions!.headers['Authorization'],
          equals('Bearer valid-jwt-token'),
        );
      },
    );

    test(
      'does not attach Authorization header when no session exists',
      () async {
        final client = ApiClient();
        RequestOptions? interceptedOptions;

        client.dio.httpClientAdapter = MockAdapter((options) async {
          interceptedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({'status': 'guest'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final response = await client.dio.get<Map<String, dynamic>>(
          '/api/public',
        );

        expect(response.statusCode, equals(200));
        expect(interceptedOptions!.headers['Authorization'], isNull);
      },
    );

    test('does not attempt token refresh on auth endpoints', () async {
      final client = ApiClient();

      client.dio.httpClientAdapter = MockAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'message': 'Bad credentials'}),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      expect(
        () => client.dio.post<dynamic>('/api/auth/login', data: {}),
        throwsA(isA<DioException>()),
      );
    });

    test(
      'attaches X-Correlation-Id header automatically to outgoing requests',
      () async {
        final client = ApiClient();
        RequestOptions? interceptedOptions;

        client.dio.httpClientAdapter = MockAdapter((options) async {
          interceptedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({'status': 'ok'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        await client.dio.get<dynamic>('/api/health');

        expect(interceptedOptions, isNotNull);
        final correlationId =
            interceptedOptions!.headers['X-Correlation-Id'] as String?;
        expect(correlationId, isNotNull);
        expect(correlationId, startsWith('req-'));
        expect(
          interceptedOptions!.headers['X-Request-Id'],
          equals(correlationId),
        );
      },
    );

    test('configures resilient connection and receive timeouts', () {
      final client = ApiClient();
      expect(
        client.dio.options.connectTimeout,
        equals(const Duration(seconds: 15)),
      );
      expect(
        client.dio.options.receiveTimeout,
        equals(const Duration(seconds: 20)),
      );
      expect(
        client.dio.options.sendTimeout,
        equals(const Duration(seconds: 15)),
      );
    });
  });

  group('ApiException', () {
    test('parses structured ApiErrorResponse correctly', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/classes'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/classes'),
          statusCode: 400,
          data: {
            'timestamp': '2026-11-10T16:00:00',
            'status': 400,
            'error': 'Bad Request',
            'message': 'name: O nome da turma é obrigatório',
            'path': '/api/classes',
            'correlationId': 'corr-abc-123',
            'validationErrors': {'name': 'O nome da turma é obrigatório'},
          },
        ),
      );

      final apiException = ApiException.fromDioException(dioException);
      expect(apiException.statusCode, equals(400));
      expect(
        apiException.message,
        equals('name: O nome da turma é obrigatório'),
      );
      expect(apiException.correlationId, equals('corr-abc-123'));
      expect(
        apiException.fieldError('name'),
        equals('O nome da turma é obrigatório'),
      );
      expect(apiException.isServerError, isFalse);
      expect(apiException.isConflict, isFalse);
    });

    test(
      'handles network disconnection and timeouts with user-friendly messages',
      () {
        final timeoutException = DioException(
          requestOptions: RequestOptions(path: '/api/analytics'),
          type: DioExceptionType.connectionTimeout,
        );

        final apiException = ApiException.fromDioException(timeoutException);
        expect(apiException.isTimeout, isTrue);
        expect(apiException.message, contains('demorou muito para responder'));

        final networkException = DioException(
          requestOptions: RequestOptions(path: '/api/analytics'),
          type: DioExceptionType.connectionError,
        );

        final netApiException = ApiException.fromDioException(networkException);
        expect(netApiException.isNetworkError, isTrue);
        expect(
          netApiException.message,
          contains('Não foi possível conectar ao servidor'),
        );
      },
    );
  });
}
