import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/session_store.dart';
import 'package:frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:frontend/features/auth/data/models/backend_auth_session_model.dart';
import 'package:frontend/features/auth/data/models/institution_model.dart';
import 'package:frontend/features/auth/domain/entities/authenticated_user.dart';
import 'package:frontend/features/auth/domain/entities/user_role.dart';
import 'package:frontend/features/auth/presentation/viewmodels/registration_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthRemoteDataSource extends Fake implements AuthRemoteDataSource {
  List<String> mockLanguages = ['Inglês', 'Japonês'];
  List<InstitutionModel> mockInstitutions = [
    const InstitutionModel(id: 1, name: 'CEFET', city: 'Nova Iguaçu'),
  ];
  BackendAuthSessionModel? mockSession;
  Exception? exceptionToThrow;

  @override
  Future<List<String>> fetchLanguages() async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockLanguages;
  }

  @override
  Future<List<InstitutionModel>> fetchInstitutions([String? query]) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockInstitutions;
  }

  @override
  Future<void> createStudent({
    required String name,
    required String email,
    required String password,
    required String googleId,
    required List<dynamic> languages,
    String gender = 'MASCULINO',
    int? institutionId,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }

  @override
  Future<void> createTeacher({
    required String name,
    required String email,
    required String password,
    required String googleId,
    required int institutionId,
    required List<String> taughtLanguages,
    required List<String> specializationAreas,
    required String bibliography,
    String gender = 'MASCULINO',
    List<dynamic>? documents,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }

  @override
  Future<BackendAuthSessionModel> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockSession ??
        const BackendAuthSessionModel(
          accessToken: 'reg-access',
          refreshToken: 'reg-refresh',
          user: AuthenticatedUser(
            id: '99',
            email: 'reg@duolinfo.com',
            name: 'Reg User',
          ),
          profileType: UserRole.student,
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAuthRemoteDataSource fakeRemote;
  late RegistrationViewModel viewModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.clear();
    fakeRemote = FakeAuthRemoteDataSource();
    viewModel = RegistrationViewModel(fakeRemote);
  });

  tearDown(() async {
    viewModel.dispose();
    await SessionStore.clear();
  });

  group('RegistrationViewModel', () {
    test('loadCatalog updates availableLanguages on success', () async {
      await viewModel.loadCatalog();
      expect(viewModel.isCatalogLoading, isFalse);
      expect(viewModel.availableLanguages, equals(['Inglês', 'Japonês']));
    });

    test(
      'loadCatalog caches languages and avoids redundant fetch unless forced',
      () async {
        await viewModel.loadCatalog();
        expect(viewModel.isCatalogLoaded, isTrue);
        fakeRemote.mockLanguages = ['Russo', 'Coreano'];
        await viewModel.loadCatalog();
        expect(viewModel.availableLanguages, equals(['Inglês', 'Japonês']));

        await viewModel.loadCatalog(forceRefresh: true);
        expect(viewModel.availableLanguages, equals(['Russo', 'Coreano']));
      },
    );

    test('loadCatalog falls back to default languages on error', () async {
      fakeRemote.exceptionToThrow = Exception('Catalog fetch failed');
      await viewModel.loadCatalog();
      expect(viewModel.isCatalogLoading, isFalse);
      expect(viewModel.availableLanguages, contains('Inglês'));
      expect(viewModel.availableLanguages, contains('Espanhol'));
    });

    test('searchInstitutions returns list from remote data source', () async {
      final results = await viewModel.searchInstitutions('cefet');
      expect(results.length, equals(1));
      expect(results.first.name, equals('CEFET'));
    });

    test('registerStudent creates student and signs in successfully', () async {
      fakeRemote.mockSession = const BackendAuthSessionModel(
        accessToken: 'student-tok',
        refreshToken: 'student-ref',
        user: AuthenticatedUser(
          id: '12',
          email: 'student@duolinfo.com',
          name: 'Student',
        ),
        profileType: UserRole.student,
      );

      final session = await viewModel.registerStudent(
        name: 'Aluno Teste',
        email: 'student@duolinfo.com',
        password: 'pass',
        languages: [
          {'languageName': 'Inglês', 'level': 'Iniciante'},
        ],
      );

      expect(session.accessToken, equals('student-tok'));
      expect(session.profileType, equals(UserRole.student));
      expect(SessionStore.hasSession, isTrue);
      expect(viewModel.isLoading, isFalse);
    });

    test('registerTeacher creates teacher and signs in successfully', () async {
      fakeRemote.mockSession = const BackendAuthSessionModel(
        accessToken: 'teacher-tok',
        refreshToken: 'teacher-ref',
        user: AuthenticatedUser(
          id: '13',
          email: 'prof@duolinfo.com',
          name: 'Prof',
        ),
        profileType: UserRole.teacher,
      );

      final session = await viewModel.registerTeacher(
        name: 'Prof Teste',
        email: 'prof@duolinfo.com',
        password: 'pass',
        institutionId: 1,
        taughtLanguages: ['Inglês'],
        specializationAreas: ['Conversação'],
        bibliography: 'Bio do professor',
      );

      expect(session.accessToken, equals('teacher-tok'));
      expect(session.profileType, equals(UserRole.teacher));
    });
  });
}
