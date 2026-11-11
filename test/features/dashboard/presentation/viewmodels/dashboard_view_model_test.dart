import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/session_store.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:frontend/features/dashboard/domain/entities/student_profile.dart';
import 'package:frontend/features/dashboard/domain/entities/teacher_profile.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:frontend/features/dashboard/domain/usecases/get_home_data.dart';
import 'package:frontend/features/dashboard/domain/usecases/logout.dart';
import 'package:frontend/features/dashboard/presentation/viewmodels/dashboard_state.dart';
import 'package:frontend/features/dashboard/presentation/viewmodels/dashboard_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDashboardRepository implements DashboardRepository {
  DashboardData? mockData;
  Exception? exceptionToThrow;
  bool logoutCalled = false;

  @override
  Future<DashboardData> getDashboardData() async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockData ??
        const DashboardData(
          user: DashboardUser(
            googleId: 'g1',
            email: 'user@duolinfo.com',
            name: 'Usuário',
          ),
          profileType: UserProfileType.student,
          profileCompleted: true,
          studentProfile: StudentProfile(
            id: 1,
            googleId: 'g1',
            name: 'Usuário',
            email: 'user@duolinfo.com',
            languages: ['Inglês'],
          ),
        );
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeDashboardRepository fakeRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.clear();
    fakeRepo = FakeDashboardRepository();
  });

  tearDown(() async {
    await SessionStore.clear();
  });

  DashboardViewModel createViewModel() {
    return DashboardViewModel(
      getHomeData: GetHomeData(fakeRepo),
      logout: Logout(fakeRepo),
    );
  }

  group('DashboardViewModel', () {
    test(
      'initializes and loads dashboard data successfully into DashboardSuccess',
      () async {
        final vm = createViewModel();
        expect(vm.state, isA<DashboardLoading>());

        await Future<void>.delayed(Duration.zero);

        expect(vm.state, isA<DashboardSuccess>());
        final success = vm.state as DashboardSuccess;
        expect(success.data.user.name, equals('Usuário'));
        expect(success.data.profileType, equals(UserProfileType.student));
        vm.dispose();
      },
    );

    test(
      'sets DashboardError with isUnauthorized when Dio throws 401',
      () async {
        fakeRepo.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: '/api/auth/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/auth/me'),
            statusCode: 401,
          ),
        );

        final vm = createViewModel();
        await Future<void>.delayed(Duration.zero);

        expect(vm.state, isA<DashboardError>());
        final errorState = vm.state as DashboardError;
        expect(errorState.isUnauthorized, isTrue);
        expect(errorState.message, contains('Sessão expirada'));
        vm.dispose();
      },
    );

    test(
      'sets DashboardError with isUnauthorized when Dio throws 403',
      () async {
        fakeRepo.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: '/api/auth/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/auth/me'),
            statusCode: 403,
          ),
        );

        final vm = createViewModel();
        await Future<void>.delayed(Duration.zero);

        expect(vm.state, isA<DashboardError>());
        final errorState = vm.state as DashboardError;
        expect(errorState.isUnauthorized, isTrue);
        vm.dispose();
      },
    );

    test(
      'sets generic connection error when Dio fails with other code',
      () async {
        fakeRepo.exceptionToThrow = DioException(
          requestOptions: RequestOptions(path: '/api/auth/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/auth/me'),
            statusCode: 500,
          ),
        );

        final vm = createViewModel();
        await Future<void>.delayed(Duration.zero);

        expect(vm.state, isA<DashboardError>());
        final errorState = vm.state as DashboardError;
        expect(errorState.isUnauthorized, isFalse);
        expect(errorState.message, contains('Falha na conexão com o servidor'));
        vm.dispose();
      },
    );

    test('changes active section and notifies listeners', () async {
      final vm = createViewModel();
      await Future<void>.delayed(Duration.zero);

      var notified = false;
      vm.addListener(() => notified = true);

      vm.setActiveSection('settings');

      expect(vm.activeSection, equals('settings'));
      expect(notified, isTrue);
      vm.dispose();
    });

    test(
      'setActiveProfileType switches active profile when available in data',
      () async {
        fakeRepo.mockData = const DashboardData(
          user: DashboardUser(
            googleId: 'g1',
            email: 'multi@duolinfo.com',
            name: 'Multi Role',
          ),
          profileType: UserProfileType.student,
          availableProfileTypes: [
            UserProfileType.student,
            UserProfileType.teacher,
          ],
          profileCompleted: true,
          studentProfile: StudentProfile(
            id: 1,
            googleId: 'g1',
            name: 'Multi Role',
            email: 'multi@duolinfo.com',
            languages: ['Inglês'],
          ),
          teacherProfile: TeacherProfile(
            id: 2,
            googleId: 'g1',
            name: 'Multi Role',
            email: 'multi@duolinfo.com',
            institution: 'CEFET',
            institutionId: 1,
            taughtLanguages: ['Inglês'],
            specializationAreas: ['Gramática'],
            bibliography: 'Bio',
          ),
        );

        final vm = createViewModel();
        await Future<void>.delayed(Duration.zero);

        expect(vm.activeProfileType, isNull);
        vm.setActiveProfileType(UserProfileType.teacher);

        expect(vm.activeProfileType, equals(UserProfileType.teacher));
        expect(vm.activeSection, equals('profile'));
        vm.dispose();
      },
    );

    test('performLogout calls repository logout', () async {
      final vm = createViewModel();
      await Future<void>.delayed(Duration.zero);

      await vm.performLogout();
      expect(fakeRepo.logoutCalled, isTrue);
      vm.dispose();
    });
  });
}
