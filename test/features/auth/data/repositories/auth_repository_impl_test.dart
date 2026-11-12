import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locale_controller.dart';
import 'package:frontend/core/network/session_store.dart';
import 'package:frontend/core/theme/app_theme_controller.dart';
import 'package:frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:frontend/features/auth/data/models/backend_auth_session_model.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:frontend/features/auth/domain/entities/authenticated_user.dart';
import 'package:frontend/features/auth/domain/entities/user_role.dart';
import 'package:frontend/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDashboardRemoteDataSource extends Fake
    implements DashboardRemoteDataSource {
  Map<String, dynamic> preferencesToReturn = {};

  @override
  Future<Map<String, dynamic>> getMyPreferences() async => preferencesToReturn;
}

class FakeAuthRemoteDataSource extends Fake implements AuthRemoteDataSource {
  BackendAuthSessionModel? mockSession;
  Exception? exceptionToThrow;

  @override
  Future<BackendAuthSessionModel> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockSession!;
  }

  @override
  Future<BackendAuthSessionModel> exchangeGoogleIdToken({
    required String idToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockSession!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAuthRemoteDataSource remoteDataSource;
  late AuthRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.clear();
    remoteDataSource = FakeAuthRemoteDataSource();
    repository = AuthRepositoryImpl(remoteDataSource);
  });

  tearDown(() async {
    await SessionStore.clear();
  });

  group('AuthRepositoryImpl', () {
    test(
      'signInWithPassword successfully activates session and sets SessionStore',
      () async {
        remoteDataSource.mockSession = const BackendAuthSessionModel(
          accessToken: 'access-token-123',
          refreshToken: 'refresh-token-456',
          user: AuthenticatedUser(
            id: '15',
            email: 'test@duolinfo.com',
            name: 'Usuário Teste',
          ),
          profileType: UserRole.student,
        );

        final session = await repository.signInWithPassword(
          'test@duolinfo.com',
          'pass123',
        );

        expect(session.accessToken, equals('access-token-123'));
        expect(session.profileType, equals(UserRole.student));
        expect(SessionStore.hasSession, isTrue);
      },
    );

    test(
      'signInWithPassword applies themeMode and uiLanguage on session activation',
      () async {
        remoteDataSource.mockSession = const BackendAuthSessionModel(
          accessToken: 'token-dark',
          refreshToken: 'refresh-dark',
          user: AuthenticatedUser(
            id: '99',
            email: 'dark@duolinfo.com',
            name: 'Dark User',
          ),
          profileType: UserRole.student,
        );

        final mockDashboardDataSource = FakeDashboardRemoteDataSource();
        mockDashboardDataSource.preferencesToReturn = {
          'themeMode': 'dark',
          'uiLanguage': 'en',
        };

        final customRepo = AuthRepositoryImpl(
          remoteDataSource,
          dashboardRemoteDataSourceFactory: () => mockDashboardDataSource,
        );

        await customRepo.signInWithPassword('dark@duolinfo.com', 'pass123');

        expect(AppThemeController.mode.value, equals(ThemeMode.dark));
        expect(AppLocaleController.languageCode.value, equals('en'));
      },
    );

    test(
      'signInWithPassword throws AuthException when session tokens are empty',
      () async {
        remoteDataSource.mockSession = const BackendAuthSessionModel(
          accessToken: '',
          refreshToken: 'ref',
          user: AuthenticatedUser(id: '15', email: 'a@b.c', name: 'Nome'),
          profileType: UserRole.student,
        );

        expect(
          () => repository.signInWithPassword('a@b.c', 'pass'),
          throwsA(isA<AuthException>()),
        );
        expect(SessionStore.hasSession, isFalse);
      },
    );

    test(
      'signInWithPassword throws AuthException when user id is missing',
      () async {
        remoteDataSource.mockSession = const BackendAuthSessionModel(
          accessToken: 'tok',
          refreshToken: 'ref',
          user: AuthenticatedUser(id: '', email: 'a@b.c', name: 'Nome'),
          profileType: UserRole.student,
        );

        expect(
          () => repository.signInWithPassword('a@b.c', 'pass'),
          throwsA(isA<AuthException>()),
        );
      },
    );

    test('signInWithIdToken activates session successfully', () async {
      remoteDataSource.mockSession = const BackendAuthSessionModel(
        accessToken: 'google-token',
        refreshToken: 'google-refresh',
        user: AuthenticatedUser(
          id: '88',
          email: 'google@duolinfo.com',
          name: 'Google User',
        ),
        profileType: UserRole.student,
      );

      final session = await repository.signInWithIdToken(
        'sample-google-id-token',
      );
      expect(session.accessToken, equals('google-token'));
      expect(SessionStore.accessToken, equals('google-token'));
    });
  });

  group('authenticationErrorMessage', () {
    test('returns direct message for AuthException', () {
      const exception = AuthException('Credenciais incorretas.');
      expect(
        authenticationErrorMessage(exception),
        equals('Credenciais incorretas.'),
      );
    });

    test('extracts custom message from DioException response data', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/login'),
          statusCode: 400,
          data: {'message': 'Conta temporariamente bloqueada.'},
        ),
      );

      expect(
        authenticationErrorMessage(dioException),
        equals('Conta temporariamente bloqueada.'),
      );
    });

    test('extracts detail from DioException response data', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/login'),
          statusCode: 400,
          data: {'detail': 'Muitas tentativas sem sucesso.'},
        ),
      );

      expect(
        authenticationErrorMessage(dioException),
        equals('Muitas tentativas sem sucesso.'),
      );
    });

    test(
      'returns polite fallback for 401 or 403 status code without body message',
      () {
        final dioException401 = DioException(
          requestOptions: RequestOptions(path: '/login'),
          response: Response(
            requestOptions: RequestOptions(path: '/login'),
            statusCode: 401,
          ),
        );

        expect(
          authenticationErrorMessage(dioException401),
          equals(
            'A autenticação foi recusada. Confira os dados e tente novamente.',
          ),
        );
      },
    );

    test('returns generic server failure for unexpected DioException', () {
      final dioException500 = DioException(
        requestOptions: RequestOptions(path: '/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/login'),
          statusCode: 500,
        ),
      );

      expect(
        authenticationErrorMessage(dioException500),
        equals('Não foi possível concluir a autenticação com o servidor.'),
      );
    });

    test('returns fallback message for unknown error object', () {
      expect(
        authenticationErrorMessage('Erro de string pura'),
        equals('Não foi possível concluir a autenticação.'),
      );
    });
  });
}
