import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app.dart';
import 'package:frontend/core/localization/app_locale_controller.dart';
import 'package:frontend/core/network/realtime_sync_service.dart';
import 'package:frontend/core/network/session_store.dart';
import 'package:frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:frontend/features/auth/domain/entities/auth_session.dart';
import 'package:frontend/features/auth/domain/entities/authenticated_user.dart';
import 'package:frontend/features/auth/domain/entities/user_role.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:frontend/features/auth/domain/usecases/sign_in_with_password.dart';
import 'package:frontend/features/auth/presentation/pages/login_page.dart';
import 'package:frontend/features/auth/presentation/pages/registration_choice_page.dart';
import 'package:frontend/features/auth/presentation/pages/student_signup_page.dart';
import 'package:frontend/features/auth/presentation/pages/teacher_signup_page.dart';
import 'package:frontend/features/auth/presentation/viewmodels/login_view_model.dart';
import 'package:frontend/features/auth/presentation/viewmodels/registration_view_model.dart';
import 'package:frontend/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:frontend/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:frontend/features/dashboard/domain/entities/student_profile.dart';
import 'package:frontend/features/dashboard/domain/entities/teacher_profile.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:frontend/features/dashboard/domain/usecases/get_home_data.dart';
import 'package:frontend/features/dashboard/domain/usecases/logout.dart';
import 'package:frontend/features/dashboard/presentation/viewmodels/dashboard_view_model.dart';
import 'package:frontend/features/dashboard/presentation/widgets/student_dashboard_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/teacher_exercises_overview_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapturedRequest {
  _CapturedRequest(this.options);

  final RequestOptions options;
}

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._handler);

  final ResponseBody Function(RequestOptions options) _handler;
  final List<_CapturedRequest> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(_CapturedRequest(options));
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Object payload, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.onSignIn});

  final Future<AuthSession> Function(String email, String password)? onSignIn;

  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => const Stream.empty();

  @override
  Future<AuthSession> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<AuthSession> signInWithIdToken(String idToken) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> signInWithPassword(String email, String password) {
    if (onSignIn != null) return onSignIn!(email, password);
    return Future.value(
      const AuthSession(
        accessToken: 'acc',
        refreshToken: 'ref',
        user: AuthenticatedUser(id: '1', email: 'a@b.com', name: 'A'),
        profileType: UserRole.student,
      ),
    );
  }

  @override
  Future<void> signOutFromGoogle() async {}
}

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository({this.onFetch});

  final Future<DashboardData> Function()? onFetch;

  @override
  Future<DashboardData> getDashboardData() {
    if (onFetch != null) return onFetch!();
    return Future.value(
      const DashboardData(
        user: DashboardUser(
          id: '1',
          googleId: 'g-1',
          email: 'aluno@escola.com',
          name: 'Aluno Teste',
        ),
        profileType: UserProfileType.student,
        availableProfileTypes: [UserProfileType.student],
        profileCompleted: true,
      ),
    );
  }

  @override
  Future<void> logout() async {}
}

String _sampleJwt({int? expSeconds}) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final exp =
      expSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': 'user-1',
        'email': 'usuario@duolinfo.dev',
        'name': 'Usuario Teste',
        'exp': exp,
      }),
    ),
  );
  return '$header.$payload.sig';
}

Map<String, dynamic> _sampleSessionJson({
  required String accessToken,
  required String refreshToken,
  String profileType = 'STUDENT',
}) {
  return {
    'token': accessToken,
    'refreshToken': refreshToken,
    'profileType': profileType,
    'user': {
      'id': 'user-1',
      'email': 'usuario@duolinfo.dev',
      'name': 'Usuario Teste',
      'googleId': 'google-sub-1',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: 'API_BASE_URL=http://127.0.0.1:1');
    RealtimeSyncService.instance.disconnect();
    await SessionStore.clear();
    SessionStore.resetSessionExpiredNotification();
    await AppLocaleController.setLanguageCode('pt');
  });

  tearDown(() async {
    RealtimeSyncService.instance.disconnect();
    await SessionStore.clear();
    SessionStore.resetSessionExpiredNotification();
    await AppLocaleController.setLanguageCode('pt');
  });

  group('SessionStore & Auth/Logout Regression Fixes', () {
    test(
      'setSession stores refreshToken and notifySessionExpired toggles notifier',
      () async {
        final token = _sampleJwt();
        await SessionStore.setSession(
          accessToken: token,
          refreshToken: 'refresh-token-abc',
        );
        RealtimeSyncService.instance.disconnect();

        expect(SessionStore.hasSession, isTrue);
        expect(SessionStore.accessToken, equals(token));
        expect(SessionStore.refreshToken, equals('refresh-token-abc'));
        expect(SessionStore.sessionExpiredNotifier.value, isFalse);

        SessionStore.notifySessionExpired();
        expect(SessionStore.sessionExpiredNotifier.value, isTrue);

        SessionStore.resetSessionExpiredNotification();
        expect(SessionStore.sessionExpiredNotifier.value, isFalse);

        await SessionStore.clear();
        expect(SessionStore.hasSession, isFalse);
        expect(SessionStore.accessToken, isNull);
        expect(SessionStore.refreshToken, isNull);
      },
    );

    test(
      'refreshAccessToken clears session when refreshToken is missing and notifies expiration',
      () async {
        SharedPreferences.setMockInitialValues({'session.active': true});
        await SessionStore.initialize();

        expect(SessionStore.hasSession, isTrue);
        expect(SessionStore.refreshToken, isNull);

        final refreshed = await SessionStore.refreshAccessToken();

        expect(refreshed, isNull);
        expect(SessionStore.hasSession, isFalse);
        expect(SessionStore.sessionExpiredNotifier.value, isTrue);
      },
    );

    test(
      'AuthRemoteDataSource sends null password when blank on signup and refreshes cleanly',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        final adapter = _MockAdapter((options) {
          if (options.path.contains('/api/auth/refresh')) {
            return _jsonResponse(
              _sampleSessionJson(
                accessToken: _sampleJwt(),
                refreshToken: _sampleJwt(),
              ),
            );
          }
          return _jsonResponse({'id': 10});
        });
        dio.httpClientAdapter = adapter;
        final remote = AuthRemoteDataSource(dio);

        await remote.createStudent(
          name: 'Maria Google',
          email: 'maria@google.com',
          password: '   ',
          googleId: 'g-123',
          languages: const ['Inglês'],
        );

        final studentBody =
            adapter.requests.last.options.data as Map<String, dynamic>;
        expect(studentBody.containsKey('password'), isTrue);
        expect(studentBody['password'], isNull);

        await remote.createTeacher(
          name: 'Prof Google',
          email: 'prof@google.com',
          password: '',
          googleId: 'g-456',
          institutionId: 3,
          taughtLanguages: const ['Inglês'],
          specializationAreas: const ['Conversação'],
          bibliography: 'Mestrado',
        );

        final teacherBody =
            adapter.requests.last.options.data as Map<String, dynamic>;
        expect(teacherBody.containsKey('password'), isTrue);
        expect(teacherBody['password'], isNull);

        await remote.refreshSession(refreshToken: 'valid-rt');
        expect(
          adapter.requests.last.options.data,
          equals({'refreshToken': 'valid-rt'}),
        );

        await remote.refreshSession(refreshToken: '   ');
        expect(adapter.requests.last.options.data, isNull);
      },
    );

    test(
      'RegistrationViewModel preserves Google session with useExistingSession and stays safe after dispose',
      () async {
        final initialAccess = _sampleJwt();
        final initialRefresh = _sampleJwt();
        final upgradedAccess = _sampleJwt();
        final upgradedRefresh = _sampleJwt();

        await SessionStore.setSession(
          accessToken: initialAccess,
          refreshToken: initialRefresh,
        );
        RealtimeSyncService.instance.disconnect();

        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        final completer = Completer<void>();
        final adapter = _MockAdapter((options) {
          if (options.path.contains('/api/auth/refresh')) {
            return _jsonResponse(
              _sampleSessionJson(
                accessToken: upgradedAccess,
                refreshToken: upgradedRefresh,
              ),
            );
          }
          return _jsonResponse({'id': 42});
        });
        dio.httpClientAdapter = adapter;

        final vm = RegistrationViewModel(AuthRemoteDataSource(dio));
        final session = await vm.registerStudent(
          name: 'Aluno Google',
          email: 'aluno@google.com',
          password: '',
          languages: const ['Inglês'],
          useExistingSession: true,
        );
        RealtimeSyncService.instance.disconnect();

        expect(session.accessToken, equals(upgradedAccess));
        expect(
          adapter.requests.any(
            (r) => r.options.path.contains('/api/auth/refresh'),
          ),
          isTrue,
        );
        expect(SessionStore.accessToken, equals(upgradedAccess));

        // Post-dispose async safety
        final slowDio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        slowDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              if (options.path.contains('/api/auth/refresh')) {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: _sampleSessionJson(
                      accessToken: upgradedAccess,
                      refreshToken: upgradedRefresh,
                      profileType: 'TEACHER',
                    ),
                  ),
                );
                return;
              }
              await completer.future;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'id': 99},
                ),
              );
            },
          ),
        );
        final disposableVm = RegistrationViewModel(
          AuthRemoteDataSource(slowDio),
        );
        final pending = disposableVm.registerTeacher(
          name: 'Prof',
          email: 'prof@escola.com',
          password: '',
          institutionId: 1,
          taughtLanguages: const ['Inglês'],
          specializationAreas: const ['Gramática'],
          bibliography: 'Bio',
          useExistingSession: true,
        );
        disposableVm.dispose();
        completer.complete();
        await pending;
        RealtimeSyncService.instance.disconnect();
      },
    );

    test(
      'LoginViewModel and DashboardViewModel handle async completion safely after dispose',
      () async {
        final loginCompleter = Completer<AuthSession>();
        final loginVm = LoginViewModel(
          SignInWithPassword(
            _FakeAuthRepository(onSignIn: (_, _) => loginCompleter.future),
          ),
          SignInWithGoogle(_FakeAuthRepository()),
        );
        final loginFuture = loginVm.signInWithPassword('a@b.com', '123456');
        loginVm.dispose();
        loginCompleter.complete(
          const AuthSession(
            accessToken: 'acc',
            refreshToken: 'ref',
            user: AuthenticatedUser(id: '1', email: 'a@b.com', name: 'A'),
            profileType: UserRole.student,
          ),
        );
        await loginFuture;

        final dashboardCompleter = Completer<DashboardData>();
        final dashVm = DashboardViewModel(
          getHomeData: GetHomeData(
            _FakeDashboardRepository(onFetch: () => dashboardCompleter.future),
          ),
          logout: Logout(_FakeDashboardRepository()),
        );
        dashVm.dispose();
        dashboardCompleter.complete(
          const DashboardData(
            user: DashboardUser(
              id: '1',
              googleId: 'g-1',
              email: 'a@b.com',
              name: 'A',
            ),
            profileType: UserProfileType.student,
            availableProfileTypes: [UserProfileType.student],
            profileCompleted: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'DashboardRepositoryImpl.logout calls onGoogleSignOut and clears SessionStore even when remote throws',
      () async {
        await SessionStore.setSession(
          accessToken: _sampleJwt(),
          refreshToken: _sampleJwt(),
        );
        RealtimeSyncService.instance.disconnect();

        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        dio.httpClientAdapter = _MockAdapter(
          (_) => _jsonResponse({}, statusCode: 500),
        );

        var googleSignedOut = false;
        final repo = DashboardRepositoryImpl(
          DashboardRemoteDataSource(dio),
          onGoogleSignOut: () async {
            googleSignedOut = true;
            throw Exception('plugin error');
          },
        );

        await repo.logout();

        expect(googleSignedOut, isTrue);
        expect(SessionStore.hasSession, isFalse);
        expect(SessionStore.accessToken, isNull);
        expect(SessionStore.refreshToken, isNull);
      },
    );
  });

  group('UI Navigation, Signup & Dashboard Regression Fixes', () {
    testWidgets(
      'App preserves navigation stack on locale change and resets to LoginPage on session expiry',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const App());
        await tester.pumpAndSettle();

        expect(find.byType(LoginPage), findsOneWidget);

        await tester.tap(find.text('Cadastre-se'));
        await tester.pumpAndSettle();
        expect(find.byType(RegistrationChoicePage), findsOneWidget);

        await AppLocaleController.setLanguageCode('en');
        await tester.pumpAndSettle();
        expect(find.byType(RegistrationChoicePage), findsOneWidget);

        SessionStore.notifySessionExpired();
        await tester.pumpAndSettle();
        expect(find.byType(RegistrationChoicePage), findsNothing);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(SessionStore.sessionExpiredNotifier.value, isFalse);
      },
    );

    testWidgets(
      'StudentSignupPage shows optional password fields for authenticated Google user',
      (tester) async {
        await SessionStore.setSession(
          accessToken: _sampleJwt(),
          refreshToken: _sampleJwt(),
        );
        RealtimeSyncService.instance.disconnect();

        await tester.pumpWidget(
          const ShadApp(
            home: StudentSignupPage(
              initialEmail: 'google.student@gmail.com',
              initialName: 'Estudante Google',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Senha (opcional para conta Google)'), findsOneWidget);
        expect(find.text('Confirmar senha (opcional)'), findsOneWidget);

        RealtimeSyncService.instance.disconnect();
        await SessionStore.clear();
      },
    );

    testWidgets(
      'TeacherSignupPage shows optional password for Google user and back button returns from step 2 to step 1',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await SessionStore.setSession(
          accessToken: _sampleJwt(),
          refreshToken: _sampleJwt(),
        );
        RealtimeSyncService.instance.disconnect();

        await tester.pumpWidget(
          const ShadApp(
            home: TeacherSignupPage(
              initialEmail: 'google.teacher@gmail.com',
              initialName: 'Docente Google',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cadastro de professor'), findsOneWidget);
        expect(find.text('Senha (opcional para conta Google)'), findsOneWidget);

        final continueBtn = find.text('Continuar');
        await tester.ensureVisible(continueBtn);
        await tester.tap(continueBtn);
        await tester.pumpAndSettle();

        expect(find.text('Perfil de professor'), findsOneWidget);

        await tester.tap(find.text('Dados da conta'));
        await tester.pumpAndSettle();

        expect(find.text('Cadastro de professor'), findsOneWidget);

        RealtimeSyncService.instance.disconnect();
        await SessionStore.clear();
      },
    );

    testWidgets(
      'StudentDashboardView defaults streak to 0 and XP to 0 when progress is empty',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const data = DashboardData(
          user: DashboardUser(
            id: '10',
            googleId: 'g-10',
            email: 'zero@duolinfo.dev',
            name: 'Novo Estudante',
          ),
          profileType: UserProfileType.student,
          availableProfileTypes: [UserProfileType.student],
          profileCompleted: true,
          studentProfile: StudentProfile(
            id: 10,
            googleId: 'g-10',
            name: 'Novo Estudante',
            email: 'zero@duolinfo.dev',
            languages: ['Inglês'],
          ),
        );

        await tester.pumpWidget(
          const ShadApp(
            home: Scaffold(
              body: StudentDashboardView(data: data, activeSection: 'profile'),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));

        expect(find.text('0 dias'), findsOneWidget);
        expect(find.text('0 XP'), findsNWidgets(2));
      },
    );

    testWidgets(
      'TeacherExercisesOverviewScreen renders empty classes safely without StateError',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const data = DashboardData(
          user: DashboardUser(
            id: '20',
            googleId: 'g-20',
            email: 'docente@duolinfo.dev',
            name: 'Professor Sem Turma',
          ),
          profileType: UserProfileType.teacher,
          availableProfileTypes: [UserProfileType.teacher],
          profileCompleted: true,
          teacherProfile: TeacherProfile(
            id: 20,
            googleId: 'g-20',
            name: 'Professor Sem Turma',
            email: 'docente@duolinfo.dev',
            institution: 'Instituto Duolinfo',
            institutionId: 1,
            taughtLanguages: ['Inglês'],
            specializationAreas: ['Gramática'],
          ),
        );

        await tester.pumpWidget(
          ShadApp(
            home: Scaffold(
              body: TeacherExercisesOverviewScreen(
                data: data,
                exercises: const [],
                submissions: const [],
                onCreateExercise: () {},
                onRefresh: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nenhuma turma vinculada'), findsOneWidget);
      },
    );
  });
}
