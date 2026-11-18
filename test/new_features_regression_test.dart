import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/realtime_sync_service.dart';
import 'package:frontend/core/network/session_store.dart';
import 'package:frontend/core/ui/language_flag.dart';
import 'package:frontend/core/ui/motion_kit.dart';
import 'package:frontend/core/ui/vivid_icon_palette.dart';
import 'package:frontend/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:frontend/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:frontend/features/dashboard/domain/entities/student_profile.dart';
import 'package:frontend/features/dashboard/domain/entities/teacher_class_assignment.dart';
import 'package:frontend/features/dashboard/domain/entities/teacher_profile.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/presentation/widgets/admin/admin_audit_logs_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/personalized_learning_path_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/pronunciation_practice_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/srs_review_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/student_notifications_dialog.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/teacher_class_analytics_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/app_user_avatar.dart';
import 'package:frontend/features/dashboard/presentation/widgets/class_performance_line_chart_card.dart';
import 'package:frontend/features/dashboard/presentation/widgets/dashboard_shell.dart';
import 'package:frontend/features/dashboard/presentation/widgets/dashboard_sidebar.dart';
import 'package:frontend/features/dashboard/presentation/widgets/entity_picture_picker_dialog.dart';
import 'package:frontend/features/dashboard/presentation/widgets/learning_features.dart';
import 'package:frontend/features/dashboard/presentation/widgets/teacher_create_exercise_screen.dart';
import 'package:frontend/features/dashboard/presentation/widgets/teacher_exercise_preview_screen.dart';
import 'package:frontend/features/dashboard/presentation/widgets/teacher_exercises_overview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _JsonHttpAdapter implements HttpClientAdapter {
  _JsonHttpAdapter(this._responder);

  final ResponseBody Function(RequestOptions options) _responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Object payload, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: 'API_BASE_URL=http://127.0.0.1:1');
    RealtimeSyncService.instance.disconnect();
    await SessionStore.clear();
  });

  tearDown(() async {
    RealtimeSyncService.instance.disconnect();
    await SessionStore.clear();
  });

  group('Per-question Mascot Tips & Standardized Dropdowns', () {
    testWidgets(
      'TeacherCreateExerciseScreen uses per-question Bode Branco tips and standardized flags/emojis',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const data = DashboardData(
          user: DashboardUser(
            id: '20',
            googleId: 'g-20',
            email: 'prof@duolinfo.dev',
            name: 'Prof Teste',
          ),
          profileType: UserProfileType.teacher,
          availableProfileTypes: [UserProfileType.teacher],
          profileCompleted: true,
          teacherProfile: TeacherProfile(
            id: 20,
            googleId: 'g-20',
            name: 'Prof Teste',
            email: 'prof@duolinfo.dev',
            institution: 'Instituto Teste',
            institutionId: 1,
            taughtLanguages: ['Inglês', 'Espanhol'],
            specializationAreas: ['Gramática'],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherCreateExerciseScreen(
                data: data,
                proficiencyLevels: const ['Fácil', 'Médio', 'Difícil'],
                exercises: const [],
                onBack: () {},
                onSaved: () async {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Activity-wide tip is removed from Informações do Exercício
        expect(
          find.text('Dica do Bode Branco para esta atividade (opcional)'),
          findsNothing,
        );

        // Per-question tip renders inside Question 1
        expect(
          find.text('Dica do Bode Branco para esta questão (opcional)'),
          findsOneWidget,
        );

        // Language flags and difficulty emojis replace colored circle dots
        expect(find.byType(LanguageFlag), findsWidgets);
        expect(find.text('🌱'), findsOneWidget);
        expect(find.byIcon(Icons.circle), findsNothing);

        // Add a second question and verify both questions have independent tips
        final addBtn = find.text('Nova questão');
        await tester.ensureVisible(addBtn);
        await tester.tap(addBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          find.text('Dica do Bode Branco para esta questão (opcional)'),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      'TeacherExercisePreviewScreen supports per-question Bode Branco tips',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TeacherExercisePreviewScreen(
              title: 'Revisão Present Simple',
              category: 'Gramática',
              theme: 'Verbos',
              level: 'Fácil',
              questions: [
                {
                  'prompt': 'She ___ to school.',
                  'style': 'Múltipla Escolha',
                  'options': ['go', 'goes'],
                  'expectedAnswer': 'goes',
                  'mascotHelpMessage': 'Observe a 3ª pessoa do singular!',
                },
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dica do Bode Branco — Questão 1'), findsOneWidget);
        expect(find.text('Observe a 3ª pessoa do singular!'), findsOneWidget);
      },
    );

    testWidgets(
      'TeacherExercisesOverviewScreen EditExerciseDialog edits per-question tips',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final overviewDio = Dio(BaseOptions(baseUrl: 'http://localhost'));
        overviewDio.httpClientAdapter = _JsonHttpAdapter((options) {
          if (options.uri.path.startsWith('/api/students/class/')) {
            return _jsonResponse(const <dynamic>[]);
          }
          return _jsonResponse(const <String, dynamic>{}, statusCode: 404);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherExercisesOverviewScreen(
                data: const DashboardData(
                  user: DashboardUser(
                    id: '20',
                    googleId: 'g-20',
                    email: 'prof@duolinfo.dev',
                    name: 'Prof Teste',
                  ),
                  profileType: UserProfileType.teacher,
                  availableProfileTypes: [UserProfileType.teacher],
                  profileCompleted: true,
                  teacherProfile: TeacherProfile(
                    id: 20,
                    googleId: 'g-20',
                    name: 'Prof Teste',
                    email: 'prof@duolinfo.dev',
                    institution: 'Instituto Teste',
                    institutionId: 1,
                    taughtLanguages: ['Inglês'],
                    specializationAreas: ['Gramática'],
                  ),
                  teacherAssignments: [
                    TeacherClassAssignment(
                      id: 1,
                      schoolClassId: 10,
                      schoolClassName: 'Turma Inglês',
                      startDate: '2026-02-01',
                      endDate: null,
                      reason: 'Docente',
                    ),
                  ],
                ),
                dio: overviewDio,
                exercises: const [
                  {
                    'id': 1,
                    'title': 'Atividade Per-Question',
                    'category': 'Gramática',
                    'theme': 'Verbos',
                    'languageName': 'Inglês',
                    'proficiencyLevel': 'Fácil',
                    'schoolClassId': 10,
                    'questions': [
                      {
                        'style': 'Múltipla Escolha',
                        'question': 'Q1 prompt',
                        'options': ['A', 'B'],
                        'correctAnswer': 'A',
                        'mascotHelpMessage': 'Dica 1 editável',
                      },
                      {
                        'style': 'Múltipla Escolha',
                        'question': 'Q2 prompt',
                        'options': ['C', 'D'],
                        'correctAnswer': 'D',
                        'mascotHelpMessage': 'Dica 2 editável',
                      },
                    ],
                  },
                ],
                submissions: const [],
                onCreateExercise: () {},
                onRefresh: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Verbos'));
        await tester.pumpAndSettle();

        expect(find.text('Dica do Bode (2)'), findsOneWidget);

        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();

        expect(
          find.text('Dicas do Bode Branco por questão (opcional)'),
          findsOneWidget,
        );
        expect(find.text('Dica da Questão 1 (opcional)'), findsOneWidget);
        expect(find.text('Dica da Questão 2 (opcional)'), findsOneWidget);
        expect(find.text('Dica 1 editável'), findsOneWidget);
        expect(find.text('Dica 2 editável'), findsOneWidget);
      },
    );
  });

  group('Real-time Notifications', () {
    test(
      'DashboardRepositoryImpl fetches unread notification count for students',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          final path = options.uri.path;
          if (path.contains('/api/auth/me') || path.contains('/api/home')) {
            return _jsonResponse({
              'profileType': 'STUDENT',
              'roles': ['STUDENT'],
              'profileCompleted': true,
              'user': {
                'id': '7',
                'googleId': 'g-7',
                'email': 'aluno@duolinfo.dev',
                'name': 'Aluno',
              },
            });
          }
          if (path == '/api/students/me/notifications/unread-count') {
            return _jsonResponse({'unreadCount': 4});
          }
          if (path == '/api/students/me') {
            return _jsonResponse({
              'id': 7,
              'googleId': 'g-7',
              'name': 'Aluno',
              'email': 'aluno@duolinfo.dev',
              'languages': ['Inglês'],
            });
          }
          if (path.contains('/enrollments')) {
            return _jsonResponse([]);
          }
          return _jsonResponse({});
        });

        final repo = DashboardRepositoryImpl(DashboardRemoteDataSource(dio));
        final result = await repo.getDashboardData();
        expect(result.unreadNotificationsCount, 4);
      },
    );

    testWidgets(
      'DashboardShell displays real-time notification banner immediately on NOTIFICATION_ADDED SSE event',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const data = DashboardData(
          user: DashboardUser(
            id: '7',
            googleId: 'g-7',
            email: 'aluno@duolinfo.dev',
            name: 'Aluno Tempo Real',
          ),
          profileType: UserProfileType.student,
          availableProfileTypes: [UserProfileType.student],
          profileCompleted: true,
          unreadNotificationsCount: 2,
          studentProfile: StudentProfile(
            id: 7,
            googleId: 'g-7',
            name: 'Aluno Tempo Real',
            email: 'aluno@duolinfo.dev',
            languages: ['Inglês'],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DashboardShell(
              data: data,
              activeSection: 'profile',
              onSectionSelected: (_) {},
              onLogout: () {},
              onRefresh: () {},
              onProfileTypeSelected: (_) {},
            ),
          ),
        );
        await tester.pump();

        // TopBar notification badge renders unread count immediately
        expect(find.text('2'), findsWidgets);

        RealtimeSyncService.instance.emitEventForTest(
          const RealtimeSyncEvent(
            type: 'NOTIFICATION_ADDED',
            timestamp: 100,
            data: {
              'title': 'Correção em tempo real',
              'message': 'Sua atividade recebeu nota 10!',
            },
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('Correção em tempo real'), findsOneWidget);
        expect(
          find.text('Sua atividade recebeu nota 10!'),
          findsOneWidget,
        );
      },
    );
  });

  group('Class Ranking Profile Avatars & Top-3 Medals', () {
    testWidgets(
      'ClassRankingStudentTile shows AppUserAvatar and gold/silver/bronze medals beside top 3 names',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: const [
                  ClassRankingStudentTile(
                    rank: 1,
                    name: 'Ana Ouro',
                    profilePicture: 'https://cdn.example.com/ana.png',
                    isMe: true,
                    submissionsCount: 5,
                    xpEarned: 120,
                    accuracyPercent: 100.0,
                  ),
                  ClassRankingStudentTile(
                    rank: 2,
                    name: 'Bruno Prata',
                    profilePicture: null,
                    submissionsCount: 4,
                    xpEarned: 90,
                    accuracyPercent: 95.0,
                  ),
                  ClassRankingStudentTile(
                    rank: 3,
                    name: 'Carla Bronze',
                    profilePicture: null,
                    submissionsCount: 3,
                    xpEarned: 60,
                    accuracyPercent: 80.0,
                  ),
                  ClassRankingStudentTile(
                    rank: 4,
                    name: 'Diego Quarto',
                    profilePicture: null,
                    submissionsCount: 2,
                    xpEarned: 20,
                    accuracyPercent: 60.0,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AppUserAvatar), findsNWidgets(4));
        expect(find.text('🥇 Ouro'), findsOneWidget);
        expect(find.text('🥈 Prata'), findsOneWidget);
        expect(find.text('🥉 Bronze'), findsOneWidget);
        expect(find.text('#4'), findsOneWidget);
        expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
        expect(find.text('Você'), findsOneWidget);
        expect(
          find.byIcon(Icons.workspace_premium_rounded),
          findsNWidgets(3),
        );
      },
    );
  });

  group('Student Join Class Section Reload & Class Performance Line Chart', () {
    testWidgets(
      'StudentClassesView reloads only Turmas section after joining a class without calling full-screen onRefresh',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var joined = false;
        var enrollmentsReloadCount = 0;
        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          final path = options.uri.path;
          if (options.method == 'GET' &&
              path.endsWith('/api/students/me/available-classes')) {
            return _jsonResponse(
              joined
                  ? const []
                  : [
                      {
                        'id': 99,
                        'name': 'Turma Nova EN',
                        'languageName': 'Inglês',
                        'schoolName': 'CEFET',
                        'teacherName': 'Prof Ana',
                        'eligible': true,
                        'activeStudentsCount': 1,
                      },
                    ],
            );
          }
          if (options.method == 'POST' &&
              path.endsWith('/api/students/me/enrollments')) {
            joined = true;
            return _jsonResponse({
              'id': 501,
              'studentId': 10,
              'schoolClassId': 99,
              'schoolClassName': 'Turma Nova EN',
              'languageName': 'Inglês',
              'schoolName': 'CEFET',
              'status': 'ACTIVE',
              'enrollmentDate': '2026-11-18',
            }, statusCode: 201);
          }
          if (options.method == 'GET' &&
              path.endsWith('/api/students/10/enrollments')) {
            enrollmentsReloadCount++;
            return _jsonResponse(
              joined
                  ? [
                      {
                        'id': 501,
                        'studentId': 10,
                        'schoolClassId': 99,
                        'schoolClassName': 'Turma Nova EN',
                        'languageName': 'Inglês',
                        'schoolName': 'CEFET',
                        'status': 'ACTIVE',
                        'enrollmentDate': '2026-11-18',
                      },
                    ]
                  : const [],
            );
          }
          return _jsonResponse(const {});
        });

        const studentData = DashboardData(
          user: DashboardUser(
            id: '10',
            googleId: 'g-10',
            email: 'aluno@duolinfo.dev',
            name: 'Aluno Teste',
          ),
          profileType: UserProfileType.student,
          availableProfileTypes: [UserProfileType.student],
          profileCompleted: true,
          studentProfile: StudentProfile(
            id: 10,
            googleId: 'g-10',
            name: 'Aluno Teste',
            email: 'aluno@duolinfo.dev',
            institutionName: 'CEFET',
            institutionId: 1,
            languages: ['Inglês'],
          ),
        );

        var fullRefreshCount = 0;
        var silentRefreshCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentClassesView(
                data: studentData,
                onRefresh: () => fullRefreshCount++,
                onSilentRefresh: () => silentRefreshCount++,
                dio: dio,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Turmas Disponíveis para Ingressar'), findsOneWidget);
        expect(find.text('Turma Nova EN'), findsOneWidget);
        expect(find.text('Participar'), findsOneWidget);
        expect(find.text('Turmas Ativas'), findsNothing);

        await tester.tap(find.text('Participar'));
        await tester.pumpAndSettle();

        expect(fullRefreshCount, 0);
        expect(silentRefreshCount, 1);
        expect(enrollmentsReloadCount, greaterThanOrEqualTo(1));
        expect(find.text('Turmas Ativas'), findsOneWidget);
        expect(find.text('Turma Nova EN'), findsOneWidget);
        expect(find.text('Participar'), findsNothing);
      },
    );

    testWidgets(
      'ClassPerformanceLineChartCard renders multi-metric LineChart, trend badge, series chips, and summary fallback',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const ClassPerformanceLineChartCard(
                      dashboard: {
                        'averageAccuracyPercent': 90.0,
                        'totalXpEarned': 85,
                        'performanceSeries': [
                          {
                            'label': 'Ativ. 1',
                            'accuracyPercent': 60.0,
                            'participationPercent': 50.0,
                            'xpProgressPercent': 35.0,
                            'overallScorePercent': 52.0,
                            'submissionsCount': 1,
                            'cumulativeXp': 20,
                          },
                          {
                            'label': 'Ativ. 2',
                            'accuracyPercent': 90.0,
                            'participationPercent': 100.0,
                            'xpProgressPercent': 75.0,
                            'overallScorePercent': 88.0,
                            'submissionsCount': 2,
                            'cumulativeXp': 85,
                          },
                        ],
                      },
                    ),
                    const ClassPerformanceLineChartCard(
                      dashboard: {
                        'averageAccuracyPercent': 78.0,
                        'totalXpEarned': 40,
                        'totalStudents': 2,
                        'totalSubmissions': 1,
                        'totalExercises': 1,
                        'exercises': [
                          {
                            'title': 'Diagnostico',
                            'averageAccuracyPercent': 78.0,
                            'submissionsCount': 1,
                          },
                        ],
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LineChart), findsNWidgets(2));
        expect(find.text('Curva de Desempenho da Turma'), findsNWidgets(2));
        expect(find.text('88.0% (+36.0%)'), findsOneWidget);
        expect(find.text('Índice Geral: 88%'), findsOneWidget);
        expect(find.text('Acurácia %: 90%'), findsOneWidget);
        expect(find.text('Participação %: 100%'), findsOneWidget);
        expect(find.text('Participação %: 50%'), findsOneWidget);
        expect(find.text('Evolução XP %: 75%'), findsOneWidget);

        await tester.tap(find.text('Participação %: 100%'));
        await tester.pumpAndSettle();

        expect(find.byType(LineChart), findsNWidgets(2));
      },
    );
  });

  group('Vivid Semantic Icon Palette Across UI', () {
    test('VividIconPalette assigns semantic vivid colors for trophies, fire, green checks, and domains', () {
      expect(
        VividIconPalette.colorFor(Icons.emoji_events_rounded),
        VividIconPalette.yellow,
      );
      expect(
        VividIconPalette.colorFor(
          Icons.emoji_events_rounded,
          brightness: Brightness.dark,
        ),
        VividIconPalette.yellowBright,
      );
      expect(
        VividIconPalette.colorFor(Icons.local_fire_department_rounded),
        VividIconPalette.orange,
      );
      expect(
        VividIconPalette.colorFor(Icons.task_alt_rounded),
        VividIconPalette.green,
      );
      expect(
        VividIconPalette.colorFor(Icons.check_circle_rounded),
        VividIconPalette.green,
      );
      expect(
        VividIconPalette.colorFor(Icons.track_changes_rounded),
        VividIconPalette.green,
      );
      expect(
        VividIconPalette.colorFor(Icons.bolt_rounded),
        VividIconPalette.purple,
      );
    });

    testWidgets(
      'DashboardSidebar renders semantic vivid colors for unselected icons too',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardSidebar(
                profileType: UserProfileType.student,
                activeSection: 'profile',
                onSectionSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final trophyIcon = tester.widget<Icon>(
          find.byIcon(Icons.emoji_events_outlined),
        );
        expect(
          trophyIcon.color?.toARGB32(),
          VividIconPalette.yellow.withValues(alpha: 0.88).toARGB32(),
        );

        final mistakesIcon = tester.widget<Icon>(
          find.byIcon(Icons.rule_folder_rounded),
        );
        expect(
          mistakesIcon.color?.toARGB32(),
          VividIconPalette.red.withValues(alpha: 0.88).toARGB32(),
        );

        final aiIcon = tester.widget<Icon>(
          find.byIcon(Icons.smart_toy_rounded),
        );
        expect(
          aiIcon.color?.toARGB32(),
          VividIconPalette.violet.withValues(alpha: 0.88).toARGB32(),
        );
      },
    );
  });

  group('All-Language Pronunciation, SRS & Learning Path Full Question Screen', () {
    testWidgets(
      'PronunciationPracticeView renders challenges across non-EN/ES languages like Japonês',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          final lang = options.queryParameters['language']?.toString() ?? 'Inglês';
          if (lang == 'Japonês') {
            return _jsonResponse([
              {
                'id': 201,
                'language': 'Japonês',
                'cefrLevel': 'A1',
                'category': 'Cumprimentos',
                'phraseText': 'おはようございます はじめまして',
                'phoneticGuide': '/o-ha-yō go-za-i-ma-su/',
                'translation': 'Bom dia! Muito prazer em conhecê-lo(a).',
                'phoneticTips': 'Mantenha cada sílaba com ritmo uniforme.',
              },
            ]);
          }
          return _jsonResponse([
            {
              'id': 101,
              'language': lang,
              'cefrLevel': 'A1',
              'category': 'Cumprimentos',
              'phraseText': 'Good morning!',
              'phoneticGuide': '/ɡʊd mɔːrnɪŋ/',
              'translation': 'Bom dia!',
              'phoneticTips': 'Fale naturalmente.',
            },
          ]);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PronunciationPracticeView(onBack: () {}, dio: dio),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Good morning!'), findsOneWidget);

        await tester.tap(find.text('Japonês'));
        await tester.pumpAndSettle();

        expect(find.text('おはようございます はじめまして'), findsOneWidget);
        expect(
          find.text('Mantenha cada sílaba com ritmo uniforme.'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'SrsReviewView provides all 6 language chips, maps backend dueToday/masteredCount stats, and loads flashcards',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          final lang = options.queryParameters['language']?.toString() ?? 'Inglês';
          if (options.uri.path.endsWith('/api/srs/session')) {
            return _jsonResponse([
              {
                'id': lang == 'Japonês' ? 22 : 11,
                'languageName': lang,
                'term': lang == 'Japonês' ? 'おはようございます' : 'overwhelmed',
                'translation': lang == 'Japonês'
                    ? 'bom dia (formal)'
                    : 'sobrecarregado(a)',
                'exampleSentence': 'Exemplo $lang',
                'exampleTranslation': 'Tradução exemplo',
                'proficiencyLevel': 'A1',
                'repetitionNumber': 0,
                'intervalDays': 1,
              },
            ]);
          }
          if (options.uri.path.endsWith('/api/srs/stats')) {
            return _jsonResponse({
              'totalCards': 6,
              'dueToday': 5,
              'completedToday': 0,
              'totalXpEarned': 25,
              'retentionRate': 94.0,
              'masteredCount': 1,
              'learningCount': 5,
            });
          }
          return _jsonResponse(const {});
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SrsReviewView(onBack: () {}, dio: dio),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('5'), findsOneWidget); // Para hoje (dueToday)
        expect(find.text('1'), findsWidgets); // Próximos dias & Dominados
        expect(find.text('94.0%'), findsOneWidget);
        expect(find.text('overwhelmed'), findsOneWidget);
        expect(find.text('Alemão'), findsOneWidget);
        expect(find.text('Japonês'), findsOneWidget);

        await tester.tap(find.text('Japonês'));
        await tester.pumpAndSettle();

        expect(find.text('おはようございます'), findsOneWidget);
      },
    );

    testWidgets(
      'PersonalizedLearningPathView opens Praticar & Concluir in full LearningExerciseRunPage instead of AlertDialog',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          final path = options.uri.path;
          if (path.endsWith('/api/learning-path/me')) {
            final lang =
                options.queryParameters['language']?.toString() ?? 'Francês';
            return _jsonResponse({
              'id': 1,
              'studentId': 10,
              'language': lang,
              'currentCefrLevel': 'A1',
              'targetCefrLevel': 'B2',
              'dailyGoalMinutes': 15,
              'currentStreakDays': 2,
              'overallProgressPercent': 0.0,
              'grammarCompetence': 20.0,
              'vocabularyCompetence': 25.0,
              'listeningCompetence': 18.0,
              'speakingCompetence': 15.0,
              'readingCompetence': 28.0,
              'writingCompetence': 19.0,
              'modules': [
                for (var i = 1; i <= 8; i++)
                  {
                    'moduleId': 500 + i,
                    'language': lang,
                    'cefrLevel': i <= 2
                        ? 'A1'
                        : (i <= 4 ? 'A2' : (i <= 6 ? 'B1' : 'B2')),
                    'moduleOrder': i,
                    'title': 'Módulo $i ($lang)',
                    'description': 'Descrição do módulo $i',
                    'category': 'Fundamentos',
                    'status': i == 1 ? 'IN_PROGRESS' : 'LOCKED',
                    'requiredXp': 40,
                  },
              ],
            });
          }
          if (path.endsWith('/api/learning-path/modules/501/quiz')) {
            return _jsonResponse([
              {
                'id': 1,
                'cefrLevel': 'A1',
                'category': 'Gramática',
                'prompt': 'Complete: Je ___ étudiant.',
                'options': ['es', 'suis', 'est', 'sommes'],
                'mascotHelpMessage': 'Com Je use o verbo être na 1ª pessoa.',
              },
              {
                'id': 2,
                'cefrLevel': 'A1',
                'category': 'Vocabulário',
                'prompt': 'Qual significa Boa noite ao chegar?',
                'options': ['Bonsoir', 'Merci', 'Pardon', 'Salut'],
                'mascotHelpMessage': 'Bonsoir é usado ao anoitecer.',
              },
            ]);
          }
          if (path.endsWith('/api/learning-path/modules/501/quiz-submit')) {
            return _jsonResponse({
              'passed': true,
              'correctCount': 2,
              'totalCount': 2,
              'scorePercent': 100.0,
              'xpEarned': 40,
              'feedback': 'Módulo concluído com 2/2 acertos (100.0%)!',
              'questionFeedback': [
                {
                  'questionIndex': 0,
                  'status': 'CORRECT',
                  'isCorrect': true,
                  'studentAnswer': 'suis',
                  'correctAnswer': 'suis',
                },
                {
                  'questionIndex': 1,
                  'status': 'CORRECT',
                  'isCorrect': true,
                  'studentAnswer': 'Bonsoir',
                  'correctAnswer': 'Bonsoir',
                },
              ],
            });
          }
          return _jsonResponse(const {});
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PersonalizedLearningPathView(
                onBack: () {},
                dio: dio,
                initialLanguage: 'Francês',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Módulo 1 (Francês)'), findsOneWidget);
        expect(find.text('Módulo 8 (Francês)'), findsOneWidget);
        expect(find.text('Praticar & Concluir'), findsOneWidget);

        await tester.ensureVisible(find.text('Praticar & Concluir'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Praticar & Concluir'));
        await tester.pumpAndSettle();

        // Must open the full LearningExerciseRunPage question screen — NOT AlertDialog!
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(LearningExerciseRunPage), findsOneWidget);
        expect(
          find.text('Dica da Questão 1 (Bode Branco)'),
          findsOneWidget,
        );
        expect(find.text('Complete: Je ___ étudiant.'), findsOneWidget);

        await tester.tap(find.text('suis'));
        await tester.pump();
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(find.text('Qual significa Boa noite ao chegar?'), findsOneWidget);
        await tester.tap(find.text('Bonsoir'));
        await tester.pump();
        await tester.tap(find.text('Enviar atividade'));
        await tester.pumpAndSettle();

        expect(find.text('Revisão das Questões'), findsOneWidget);
        expect(find.text('2/2'), findsOneWidget);
        expect(find.text('+40 XP'), findsOneWidget);
      },
    );
  });

  group('Individual Ranking Podium & Leaf Non-Podium Rows', () {
    testWidgets(
      'LearningFeaturePage ranking keeps podium with avatars/medals, omits top-3 from bottom list, and shows leaf badge + #position for rank 4+',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          if (options.uri.path.endsWith('/api/exercises/rankings/individual')) {
            return _jsonResponse([
              {
                'rank': 1,
                'studentName': 'Ana Ouro',
                'xpEarned': 300,
                'activitiesCompleted': 5,
                'correctAnswers': 10,
                'questionCount': 10,
                'profilePicture': 'https://cdn.example.com/1.png',
              },
              {
                'rank': 2,
                'studentName': 'Bruno Prata',
                'xpEarned': 250,
                'activitiesCompleted': 4,
                'correctAnswers': 8,
                'questionCount': 10,
              },
              {
                'rank': 3,
                'studentName': 'Carla Bronze',
                'xpEarned': 200,
                'activitiesCompleted': 3,
                'correctAnswers': 6,
                'questionCount': 10,
              },
              {
                'rank': 4,
                'studentName': 'Diego Quarto',
                'xpEarned': 120,
                'activitiesCompleted': 2,
                'correctAnswers': 5,
                'questionCount': 8,
              },
              {
                'rank': 5,
                'studentName': 'Elena Quinta',
                'xpEarned': 80,
                'activitiesCompleted': 1,
                'correctAnswers': 3,
                'questionCount': 5,
              },
            ]);
          }
          return _jsonResponse(const []);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LearningFeaturePage(
                section: 'ranking',
                onBackToProfile: () {},
                dio: dio,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pódio tem fotos, primeiros nomes e medalhas Ouro/Prata/Bronze
        expect(find.text('Pódio de Liderança'), findsOneWidget);
        expect(find.text('🥇 Ouro'), findsOneWidget);
        expect(find.text('🥈 Prata'), findsOneWidget);
        expect(find.text('🥉 Bronze'), findsOneWidget);

        // Top 3 NÃO se duplicam na lista abaixo (apenas 1 nome completo de cada pódio ou apenas 1º nome)
        expect(find.text('Ana Ouro'), findsNothing);
        expect(find.text('Bruno Prata'), findsNothing);
        expect(find.text('Carla Bronze'), findsNothing);
        expect(find.text('Ana'), findsOneWidget);
        expect(find.text('Bruno'), findsOneWidget);
        expect(find.text('Carla'), findsOneWidget);

        // Lista abaixo exibe apenas rank >= 4 com folha e #posição
        expect(find.text('Diego Quarto'), findsOneWidget);
        expect(find.text('Elena Quinta'), findsOneWidget);
        expect(find.byIcon(Icons.eco_rounded), findsNWidgets(2));
        expect(find.text('#4'), findsOneWidget);
        expect(find.text('#5'), findsOneWidget);
        // 3 avatares do pódio + 2 da lista abaixo = 5 avatares
        expect(find.byType(AppUserAvatar), findsNWidgets(5));
      },
    );
  });

  group('Multi-Scope & Teacher Performance Rankings', () {
    testWidgets(
      'LearningFeaturePage rankings displays all 9 scopes, defaults teachers to app_teachers performance, and filters class scopes with dropdown',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final requestedScopes = <String>[];
        final requestedClassIds = <String?>[];
        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          if (options.uri.path.endsWith('/api/exercises/rankings')) {
            final scope = options.queryParameters['scope']?.toString() ?? '';
            final classId = options.queryParameters['schoolClassId']?.toString();
            requestedScopes.add(scope);
            requestedClassIds.add(classId);
            if (scope == 'app_teachers') {
              return _jsonResponse([
                {
                  'rank': 1,
                  'studentName': 'Prof Camila Lider',
                  'className': 'Turma A',
                  'schoolName': 'CEFET Alpha',
                  'xpEarned': 900,
                  'activitiesCompleted': 10,
                  'correctAnswers': 92,
                  'questionCount': 100,
                  'accuracyPercent': 92.0,
                },
                {
                  'rank': 2,
                  'studentName': 'Prof Marcos Silva',
                  'className': 'Turma B',
                  'schoolName': 'CEFET Beta',
                  'xpEarned': 700,
                  'activitiesCompleted': 8,
                  'correctAnswers': 64,
                  'questionCount': 80,
                  'accuracyPercent': 80.0,
                },
                {
                  'rank': 3,
                  'studentName': 'Prof Julia Costa',
                  'className': 'Turma C',
                  'xpEarned': 500,
                  'activitiesCompleted': 6,
                  'correctAnswers': 45,
                  'questionCount': 60,
                  'accuracyPercent': 75.0,
                },
                {
                  'rank': 4,
                  'studentName': 'Prof Rafael Dias',
                  'className': 'Turma D',
                  'schoolName': 'CEFET Alpha',
                  'xpEarned': 350,
                  'activitiesCompleted': 4,
                  'correctAnswers': 28,
                  'questionCount': 40,
                  'accuracyPercent': 70.0,
                },
              ]);
            }
            if (scope == 'class_students') {
              return _jsonResponse([
                {
                  'rank': 1,
                  'studentName': 'Lucas Turma $classId',
                  'className': classId == '20' ? 'Turma B' : 'Turma A',
                  'xpEarned': 420,
                  'activitiesCompleted': 4,
                  'correctAnswers': 19,
                  'questionCount': 20,
                  'accuracyPercent': 95.0,
                },
              ]);
            }
            if (scope == 'schools') {
              return _jsonResponse([
                {
                  'rank': 1,
                  'studentName': 'Escola Alpha',
                  'className': 'Nova Iguaçu',
                  'schoolName': 'Escola Alpha',
                  'xpEarned': 3400,
                  'activitiesCompleted': 20,
                  'correctAnswers': 85,
                  'questionCount': 100,
                  'accuracyPercent': 85.0,
                },
              ]);
            }
          }
          return _jsonResponse(const []);
        });

        final data = DashboardData(
          user: const DashboardUser(
            googleId: 'g-prof',
            email: 'prof@test.local',
            name: 'Prof Teste',
          ),
          profileType: UserProfileType.teacher,
          profileCompleted: true,
          teacherProfile: const TeacherProfile(
            id: 7,
            googleId: 'g-prof',
            name: 'Prof Teste',
            email: 'prof@test.local',
            institution: 'CEFET Alpha',
            institutionId: 5,
            taughtLanguages: ['Inglês'],
            specializationAreas: ['Gramática'],
          ),
          teacherAssignments: const [
            TeacherClassAssignment(
              id: 1,
              schoolClassId: 10,
              schoolClassName: 'Turma A',
              schoolClassLanguage: 'Inglês',
              startDate: '2026-01-01',
              endDate: null,
              reason: 'Titular',
            ),
            TeacherClassAssignment(
              id: 2,
              schoolClassId: 20,
              schoolClassName: 'Turma B',
              schoolClassLanguage: 'Espanhol',
              startDate: '2026-01-01',
              endDate: null,
              reason: 'Titular',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LearningFeaturePage(
                section: 'rankings',
                data: data,
                onBackToProfile: () {},
                dio: dio,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(requestedScopes, contains('app_teachers'));
        expect(find.text('Melhor Professor do App'), findsOneWidget);
        expect(find.text('92% acertos · 900 XP'), findsOneWidget);
        expect(find.text('Prof Rafael Dias'), findsOneWidget);
        expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
        expect(find.text('#4'), findsOneWidget);

        // Todos os 9 escopos visíveis para alternar
        for (final label in [
          'Aluno na Turma',
          'Aluno na Escola',
          'Aluno no App',
          'Turma na Escola',
          'Turma no App',
          'Escolas',
          'Prof. na Turma',
          'Prof. na Escola',
          'Prof. no App',
        ]) {
          expect(find.text(label), findsOneWidget);
        }

        // Seleciona Aluno na Turma -> usa dropdown Turma A (10) e troca para Turma B (20)
        await tester.tap(find.text('Aluno na Turma'));
        await tester.pumpAndSettle();
        expect(requestedScopes, contains('class_students'));
        expect(requestedClassIds.last, '10');
        expect(find.text('Turma: Turma A'), findsOneWidget);

        await tester.tap(find.text('Turma: Turma A'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Turma: Turma B').last);
        await tester.pumpAndSettle();
        expect(requestedClassIds.last, '20');
        expect(find.text('Lucas'), findsOneWidget);

        // Seleciona Escolas
        await tester.tap(find.text('Escolas'));
        await tester.pumpAndSettle();
        expect(requestedScopes, contains('schools'));
        expect(find.text('Escola Alpha'), findsOneWidget);
      },
    );
  });

  group('Dedicated True/False, Matching & Audio Listening Mechanics', () {
    testWidgets(
      'TeacherCreateExerciseScreen renders dedicated editors for Verdadeiro ou Falso, Correspondência and Áudio instead of Multiple Choice and serializes properly',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Map<String, dynamic>? savedPayload;
        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          if (options.uri.path.endsWith('/api/classes')) {
            return _jsonResponse([
              {'id': 10, 'name': '3 INFO Inglês', 'languageName': 'Inglês'},
            ]);
          }
          if (options.uri.path.endsWith('/api/exercises') &&
              options.method == 'POST') {
            savedPayload = Map<String, dynamic>.from(options.data as Map);
            return _jsonResponse({'id': 999});
          }
          return _jsonResponse(const []);
        });

        final data = DashboardData(
          user: const DashboardUser(
            googleId: 'g-t',
            email: 'prof@test.local',
            name: 'Prof Criador',
          ),
          profileType: UserProfileType.teacher,
          profileCompleted: true,
          teacherProfile: const TeacherProfile(
            id: 5,
            googleId: 'g-t',
            name: 'Prof Criador',
            email: 'prof@test.local',
            institution: 'CEFET',
            taughtLanguages: ['Inglês'],
            specializationAreas: ['Gramática'],
          ),
          teacherAssignments: const [
            TeacherClassAssignment(
              id: 1,
              schoolClassId: 10,
              schoolClassName: '3 INFO Inglês',
              schoolClassLanguage: 'Inglês',
              startDate: '2026-01-01',
              endDate: null,
              reason: 'Titular',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherCreateExerciseScreen(
                data: data,
                proficiencyLevels: const ['Básico', 'Intermediário'],
                exercises: const [],
                onBack: () {},
                onSaved: () async {},
                dio: dio,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleField = find.widgetWithText(
          TextFormField,
          'Título do exercício',
        );
        await tester.enterText(titleField, 'Atividade Especial');
        await tester.pump();

        final styleDropdown = find.widgetWithText(
          DropdownButtonFormField<String>,
          'Múltipla Escolha',
        );

        // 1. Trocar para Verdadeiro ou Falso -> NÃO vira múltipla escolha!
        await tester.ensureVisible(styleDropdown);
        await tester.pumpAndSettle();
        await tester.tap(styleDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Verdadeiro ou Falso').last);
        await tester.pumpAndSettle();

        expect(find.text('Gabarito (Verdadeiro ou Falso)'), findsOneWidget);
        expect(find.text('Opção A'), findsNothing);
        expect(find.text('Alternativas IA'), findsNothing);

        final tfPrompt = find.widgetWithText(
          TextFormField,
          'Digite a afirmação (Verdadeira ou Falsa)',
        );
        await tester.enterText(tfPrompt, 'Water means agua.');
        await tester.tap(find.text('Falso').last);
        await tester.pump();

        // 2. Trocar para Correspondência -> editor de pares Esquerda ↔ Direita!
        final tfDropdown = find.widgetWithText(
          DropdownButtonFormField<String>,
          'Verdadeiro ou Falso',
        );
        await tester.tap(tfDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Correspondência').last);
        await tester.pumpAndSettle();

        expect(
          find.text('Pares de Correspondência (Coluna A ↔ Coluna B)'),
          findsOneWidget,
        );
        expect(find.text('Opção A'), findsNothing);
        expect(find.text('Adicionar par'), findsOneWidget);

        // 3. Trocar para Áudio -> mecânica de escuta!
        final matchDropdown = find.widgetWithText(
          DropdownButtonFormField<String>,
          'Correspondência',
        );
        await tester.tap(matchDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Áudio').last);
        await tester.pumpAndSettle();

        expect(find.text('Mecânica de Escuta (Inglês)'), findsOneWidget);
        expect(find.text('Ouvir prévia'), findsOneWidget);
        final audioInput = find.widgetWithText(
          TextFormField,
          'Frase falada no áudio (Inglês)',
        );
        await tester.enterText(audioInput, 'Good morning everyone');
        await tester.pump();

        await tester.ensureVisible(find.text('Salvar e publicar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salvar e publicar'));
        await tester.pumpAndSettle();

        expect(savedPayload, isNotNull);
        final qList = savedPayload!['questions'] as List;
        expect(qList.first['style'], 'Áudio');
        expect(qList.first['audioText'], 'Good morning everyone');
        expect(qList.first['expectedAnswer'], 'Good morning everyone');
      },
    );

    testWidgets(
      'LearningExerciseRunPage plays dedicated Verdadeiro/Falso cards, Correspondência tap-to-pair board, and Áudio listening mechanic',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        List<String>? submittedAnswers;
        final exercise = LearningExerciseSessionData(
          id: 77,
          title: 'Prática Variada',
          category: 'Vocabulário',
          theme: 'Dia a dia',
          language: 'Inglês',
          level: 'Básico',
          className: '3 INFO',
          teacher: 'Prof Teste',
          questions: const [
            LearningExerciseQuestionData(
              'O sol nasce no leste.',
              [],
              style: 'Verdadeiro ou Falso',
              answer: 'Verdadeiro',
            ),
            LearningExerciseQuestionData(
              'Ligue cada palavra ao significado',
              ['LEFT::Apple', 'LEFT::Book', 'RIGHT::Livro', 'RIGHT::Maçã'],
              style: 'Correspondência',
              answer: 'Apple => Maçã | Book => Livro',
            ),
            LearningExerciseQuestionData(
              'Ouça o áudio e escreva o que entendeu',
              [],
              style: 'Áudio',
              answer: 'Good morning',
              audioText: 'Good morning',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LearningExerciseRunPage(
                exercise: exercise,
                dio: Dio(),
                onBack: () {},
                onFinished: () {},
                onSubmitCustom: (answers, _) async {
                  submittedAnswers = answers;
                  return {
                    'correctCount': 3,
                    'questionCount': 3,
                    'xpEarned': 30,
                    'questionFeedback': const [],
                  };
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Questão 1: Verdadeiro ou Falso
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
        await tester.tap(find.text('Verdadeiro'));
        await tester.pump();
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        // Questão 2: Correspondência (toque esquerdo -> direito)
        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Maçã'), findsOneWidget);
        await tester.tap(find.text('Apple'));
        await tester.pump();
        await tester.tap(find.text('Maçã'));
        await tester.pump();
        await tester.tap(find.text('Book'));
        await tester.pump();
        await tester.tap(find.text('Livro'));
        await tester.pump();
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        // Questão 3: Áudio (Mecânica de Escuta sem mostrar frase falada antes da acessibilidade)
        expect(find.textContaining('Mecânica de Escuta'), findsOneWidget);
        expect(find.text('Ouvir áudio'), findsOneWidget);
        expect(find.text('Transcrição acessível do áudio: "Good morning"'), findsNothing);
        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Digite exatamente o que você ouviu',
          ),
          'Good morning',
        );
        await tester.pump();
        await tester.tap(find.text('Enviar atividade'));
        await tester.pumpAndSettle();

        expect(submittedAnswers, [
          'Verdadeiro',
          'Apple => Maçã | Book => Livro',
          'Good morning',
        ]);
      },
    );

    testWidgets(
      'TeacherCreateExerciseScreen limits Conteúdos publicados to the 10 most recent items',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((_) => _jsonResponse(const []));

        // Cria 14 atividades fora de ordem cronológica para validar ordenação + limite de 10
        final exercises = [
          for (var i = 1; i <= 14; i++)
            {
              'id': i,
              'title': 'Atividade #${i.toString().padLeft(2, '0')}',
              'category': 'Gramática',
              'theme': 'Tema $i',
              'schoolClassName': '3 INFO',
              'languageName': 'Inglês',
              'createdAt': DateTime.utc(2026, 1, i).toIso8601String(),
              'questions': const [
                {'question': 'Q1', 'style': 'Múltipla Escolha', 'options': ['A', 'B']},
              ],
            },
        ];

        final data = DashboardData(
          user: const DashboardUser(
            googleId: 'g-t10',
            email: 'prof10@test.local',
            name: 'Prof Limite',
          ),
          profileType: UserProfileType.teacher,
          profileCompleted: true,
          teacherProfile: const TeacherProfile(
            id: 5,
            googleId: 'g-t10',
            name: 'Prof Limite',
            email: 'prof10@test.local',
            institution: 'CEFET',
            taughtLanguages: ['Inglês'],
            specializationAreas: ['Gramática'],
          ),
          teacherAssignments: const [
            TeacherClassAssignment(
              id: 1,
              schoolClassId: 10,
              schoolClassName: '3 INFO',
              schoolClassLanguage: 'Inglês',
              startDate: '2026-01-01',
              endDate: null,
              reason: 'Titular',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherCreateExerciseScreen(
                data: data,
                proficiencyLevels: const ['Básico'],
                exercises: exercises,
                onBack: () {},
                onSaved: () async {},
                dio: dio,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Últimos 10 de 14'), findsOneWidget);
        // 10 mais recentes (#05..#14) devem aparecer
        for (var i = 5; i <= 14; i++) {
          expect(
            find.text('Atividade #${i.toString().padLeft(2, '0')}'),
            findsOneWidget,
          );
        }
        // 4 mais antigas (#01..#04) NÃO devem aparecer
        for (var i = 1; i <= 4; i++) {
          expect(
            find.text('Atividade #${i.toString().padLeft(2, '0')}'),
            findsNothing,
          );
        }
      },
    );
  });

  group('Teacher Pending Correction Notifications', () {
    test(
      'DashboardRepositoryImpl fetches unread notification count for teachers',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          final path = options.uri.path;
          if (path.contains('/api/auth/me') || path.contains('/api/home')) {
            return _jsonResponse({
              'profileType': 'TEACHER',
              'roles': ['TEACHER'],
              'profileCompleted': true,
              'user': {
                'id': '9',
                'googleId': 'g-9',
                'email': 'prof@duolinfo.dev',
                'name': 'Prof Teste',
              },
            });
          }
          if (path == '/api/teachers/me/notifications/unread-count') {
            return _jsonResponse({'unreadCount': 3});
          }
          if (path == '/api/teachers/me') {
            return _jsonResponse({
              'id': 9,
              'googleId': 'g-9',
              'name': 'Prof Teste',
              'email': 'prof@duolinfo.dev',
              'institution': 'CEFET',
              'taughtLanguages': ['Inglês'],
              'specializationAreas': ['Escrita'],
            });
          }
          if (path.contains('/assignments')) {
            return _jsonResponse([]);
          }
          return _jsonResponse({});
        });

        final repo = DashboardRepositoryImpl(DashboardRemoteDataSource(dio));
        final result = await repo.getDashboardData();
        expect(result.unreadNotificationsCount, 3);
      },
    );

    testWidgets(
      'DashboardShell shows live CORRECTION_PENDING banner for teachers with navigation to reviewExercises, and Teacher Notifications dialog lists & navigates to grading',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var selectedSection = 'profile';
        const data = DashboardData(
          user: DashboardUser(
            id: '9',
            googleId: 'g-9',
            email: 'prof@duolinfo.dev',
            name: 'Prof Revisão',
          ),
          profileType: UserProfileType.teacher,
          availableProfileTypes: [UserProfileType.teacher],
          profileCompleted: true,
          unreadNotificationsCount: 1,
          teacherProfile: TeacherProfile(
            id: 9,
            googleId: 'g-9',
            name: 'Prof Revisão',
            email: 'prof@duolinfo.dev',
            institution: 'CEFET',
            taughtLanguages: ['Inglês'],
            specializationAreas: ['Escrita'],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DashboardShell(
              data: data,
              activeSection: 'profile',
              onSectionSelected: (section) => selectedSection = section,
              onProfileTypeSelected: (_) {},
              onLogout: () {},
              onRefresh: () {},
            ),
          ),
        );
        await tester.pump();

        expect(find.text('1'), findsWidgets);

        RealtimeSyncService.instance.emitEventForTest(
          const RealtimeSyncEvent(
            type: 'NOTIFICATION_ADDED',
            timestamp: 100,
            data: {
              'title': 'Correção pendente',
              'message':
                  'Maria Silva respondeu "Redação" e aguarda sua correção.',
              'type': 'CORRECTION_PENDING',
              'actionUrl': '/review-exercises',
            },
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.textContaining('Correção pendente (Correção Pendente)'),
          findsOneWidget,
        );
        await tester.tap(find.text('Ver'));
        await tester.pump();
        expect(selectedSection, 'reviewExercises');

        // Agora valida o diálogo de notificações do professor (/api/teachers/me/notifications)
        final dio = Dio();
        var markedRead = false;
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          if (options.uri.path == '/api/teachers/me/notifications' &&
              options.method == 'GET') {
            return _jsonResponse([
              {
                'id': 42,
                'title': 'Correção pendente',
                'message':
                    'Maria Silva respondeu "Redação" e aguarda sua correção.',
                'type': 'CORRECTION_PENDING',
                'read': false,
                'actionUrl': '/review-exercises',
              },
            ]);
          }
          if (options.uri.path == '/api/teachers/me/notifications/42/read' &&
              options.method == 'PATCH') {
            markedRead = true;
            return _jsonResponse({'id': 42, 'read': true});
          }
          return _jsonResponse({});
        });

        String? navigatedUrl;
        String? navigatedType;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentNotificationsDialog(
                endpointPrefix: '/api/teachers/me/notifications',
                dio: dio,
                onNavigateAction: (url, type) {
                  navigatedUrl = url;
                  navigatedType = type;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Correção pendente'), findsOneWidget);
        expect(find.byIcon(Icons.fact_check_rounded), findsOneWidget);
        await tester.tap(find.text('Correção pendente'));
        await tester.pumpAndSettle();

        expect(markedRead, isTrue);
        expect(navigatedUrl, '/review-exercises');
        expect(navigatedType, 'CORRECTION_PENDING');
      },
    );
  });

  group('Admin-Style Teacher Performance Telemetry Charts', () {
    testWidgets(
      'TeacherLearningPage teacherRanking renders telemetry gauges, multi-line performance curves, pie distribution, and student leaderboard without legacy BarChart',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          final path = options.uri.path;
          if (path.endsWith('/api/exercises')) {
            return _jsonResponse([
              {
                'id': 1,
                'title': 'Pronomes',
                'schoolClassId': 10,
                'schoolClassName': '3 INFO A',
              },
              {
                'id': 2,
                'title': 'Verbos',
                'schoolClassId': 20,
                'schoolClassName': '2 INFO B',
              },
            ]);
          }
          if (path.endsWith('/api/exercises/submissions')) {
            return _jsonResponse([
              {
                'id': 101,
                'exerciseId': 1,
                'exerciseTitle': 'Pronomes',
                'studentName': 'JPGMV20',
                'correctCount': 4,
                'questionCount': 5,
                'xpEarned': 20,
                'reviewStatus': 'AUTO_GRADED',
                'submittedAt': '2026-11-17T10:00:00Z',
              },
              {
                'id': 102,
                'exerciseId': 2,
                'exerciseTitle': 'Verbos',
                'studentName': 'JPGMV20',
                'correctCount': 5,
                'questionCount': 5,
                'xpEarned': 20,
                'reviewStatus': 'REVIEWED',
                'submittedAt': '2026-11-17T12:00:00Z',
              },
            ]);
          }
          if (path.endsWith('/api/catalog/proficiency-levels')) {
            return _jsonResponse(['Básico', 'Intermediário']);
          }
          return _jsonResponse(const []);
        });

        const data = DashboardData(
          user: DashboardUser(
            id: '9',
            googleId: 'g-9',
            email: 'prof@duolinfo.dev',
            name: 'Prof Desempenho',
          ),
          profileType: UserProfileType.teacher,
          profileCompleted: true,
          teacherProfile: TeacherProfile(
            id: 9,
            googleId: 'g-9',
            name: 'Prof Desempenho',
            email: 'prof@duolinfo.dev',
            institution: 'CEFET',
            taughtLanguages: ['Inglês'],
            specializationAreas: ['Gramática'],
          ),
          teacherAssignments: [
            TeacherClassAssignment(
              id: 1,
              schoolClassId: 10,
              schoolClassName: '3 INFO A',
              schoolClassLanguage: 'Inglês',
              startDate: '2026-01-01',
              endDate: null,
              reason: 'Titular',
            ),
            TeacherClassAssignment(
              id: 2,
              schoolClassId: 20,
              schoolClassName: '2 INFO B',
              schoolClassLanguage: 'Inglês',
              startDate: '2026-01-01',
              endDate: null,
              reason: 'Titular',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherLearningPage(
                data: data,
                section: 'teacherRanking',
                dio: dio,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Desempenho das atividades'), findsOneWidget);
        expect(find.byType(BarChart), findsNothing);
        expect(find.text('Gráfico de XP por Estudante'), findsNothing);

        // Gauges estilo telemetria Admin + gráficos LineChart & PieChart
        expect(find.byType(AnimatedRadialGauge), findsNWidgets(4));
        expect(find.byType(ClassPerformanceLineChartCard), findsOneWidget);
        expect(find.byType(PieChart), findsOneWidget);
        expect(
          find.text('Curva Acurácia (%) vs Evolução XP (%)'),
          findsOneWidget,
        );
        expect(find.byType(LineChart), findsNWidgets(2));
        expect(find.text('Desempenho por Estudante (1)'), findsOneWidget);
        expect(find.text('JPGMV20'), findsOneWidget);

        // Filtro por turma funcional
        expect(find.text('Todas as turmas'), findsOneWidget);
        await tester.tap(find.text('3 INFO A'));
        await tester.pumpAndSettle();
        expect(find.text('1 entregas'), findsWidgets);
      },
    );

    testWidgets(
      'TeacherClassAnalyticsView separates each class with its own Admin-style gauges and CPU/Pie graphs and drills into single class details',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          final path = options.uri.path;
          if (path == '/api/classes/10/analytics') {
            return _jsonResponse({
              'classId': 10,
              'className': '3 INFO Inglês',
              'totalStudents': 12,
              'activeStudentsPastWeek': 10,
              'averageAccuracyPercent': 86.0,
              'totalSubmissions': 24,
              'pendingGrading': 2,
              'cefrDistribution': {'A1': 5, 'A2': 7},
              'studentsNeedingAttention': [],
            });
          }
          if (path == '/api/classes/10/dashboard') {
            return _jsonResponse({
              'totalStudents': 12,
              'totalSubmissions': 24,
              'totalXpEarned': 420,
              'averageAccuracyPercent': 86.0,
              'performanceSeries': [
                {
                  'label': 'Atv 1',
                  'accuracyPercent': 80.0,
                  'participationPercent': 75.0,
                  'xpProgressPercent': 50.0,
                  'overallScorePercent': 72.0,
                  'submissionsCount': 10,
                  'cumulativeXp': 200,
                },
                {
                  'label': 'Atv 2',
                  'accuracyPercent': 86.0,
                  'participationPercent': 83.0,
                  'xpProgressPercent': 100.0,
                  'overallScorePercent': 88.0,
                  'submissionsCount': 24,
                  'cumulativeXp': 420,
                },
              ],
              'students': [
                {
                  'name': 'Ana Julia',
                  'averageAccuracyPercent': 92.0,
                  'submissionsCount': 4,
                  'xpEarned': 120,
                },
              ],
            });
          }
          if (path == '/api/classes/20/analytics') {
            return _jsonResponse({
              'classId': 20,
              'className': '2 INFO B Espanhol',
              'totalStudents': 8,
              'activeStudentsPastWeek': 6,
              'averageAccuracyPercent': 74.5,
              'totalSubmissions': 14,
              'pendingGrading': 1,
              'cefrDistribution': {'A1': 6, 'B1': 2},
              'studentsNeedingAttention': [],
            });
          }
          if (path == '/api/classes/20/dashboard') {
            return _jsonResponse({
              'totalStudents': 8,
              'totalSubmissions': 14,
              'totalXpEarned': 210,
              'averageAccuracyPercent': 74.5,
              'performanceSeries': [
                {
                  'label': 'Atv 1',
                  'accuracyPercent': 70.0,
                  'participationPercent': 62.5,
                  'xpProgressPercent': 100.0,
                  'overallScorePercent': 74.0,
                  'submissionsCount': 14,
                  'cumulativeXp': 210,
                },
              ],
              'students': [],
            });
          }
          return _jsonResponse({});
        });

        const data = DashboardData(
          user: DashboardUser(
            id: '9',
            googleId: 'g-9',
            email: 'prof@duolinfo.dev',
            name: 'Prof Analytics',
          ),
          profileType: UserProfileType.teacher,
          profileCompleted: true,
          teacherProfile: TeacherProfile(
            id: 9,
            googleId: 'g-9',
            name: 'Prof Analytics',
            email: 'prof@duolinfo.dev',
            institution: 'CEFET',
            taughtLanguages: ['Inglês', 'Espanhol'],
            specializationAreas: ['Gramática'],
          ),
          teacherAssignments: [
            TeacherClassAssignment(
              id: 1,
              schoolClassId: 10,
              schoolClassName: '3 INFO Inglês',
              schoolClassLanguage: 'Inglês',
              startDate: '2026-01-01',
              endDate: null,
              reason: 'Titular',
            ),
            TeacherClassAssignment(
              id: 2,
              schoolClassId: 20,
              schoolClassName: '2 INFO B Espanhol',
              schoolClassLanguage: 'Espanhol',
              startDate: '2026-01-01',
              endDate: null,
              reason: 'Titular',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TeacherClassAnalyticsView(
              data: data,
              onBack: () {},
              dio: dio,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Visão separada padrão mostra ambas turmas com seus próprios gráficos
        expect(find.text('Todas separadas (2)'), findsOneWidget);
        expect(
          find.text('Curva de Desempenho — 3 INFO Inglês'),
          findsOneWidget,
        );
        expect(
          find.text('Curva de Desempenho — 2 INFO B Espanhol'),
          findsOneWidget,
        );
        expect(find.byType(AnimatedRadialGauge), findsNWidgets(8));
        expect(find.byType(ClassPerformanceLineChartCard), findsNWidgets(2));
        expect(find.byType(PieChart), findsNWidgets(2));

        // Focar em uma turma exibe lista de estudantes e alertas da turma selecionada
        await tester.tap(find.text('3 INFO Inglês').first);
        await tester.pumpAndSettle();

        expect(find.byType(ClassPerformanceLineChartCard), findsOneWidget);
        expect(find.text('Estudantes da Turma (1)'), findsOneWidget);
        expect(find.text('#1 · Ana Julia'), findsOneWidget);
        expect(
          find.text('Alunos que Precisam de Atenção (0)'),
          findsOneWidget,
        );
      },
    );
  });

  group('Modern Admin Logs (30-Day Separated Files + Structured Audit)', () {
    testWidgets(
      'displays 30-day separated backend log files, filters severity, switches files and switches to structured audit tab',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          if (options.path == '/api/admin/logs/files' &&
              options.method == 'GET') {
            return _jsonResponse({
              'retentionDays': 30,
              'logDirectory': '/app/logs',
              'totalFiles': 3,
              'totalSizeBytes': 15360,
              'files': [
                {
                  'fileName': 'application.log',
                  'channel': 'application',
                  'label': 'Aplicação Geral',
                  'date': '2026-11-18',
                  'compressed': false,
                  'sizeBytes': 8192,
                  'lastModified': '2026-11-18T12:00:00Z',
                },
                {
                  'fileName': 'errors.log',
                  'channel': 'errors',
                  'label': 'Erros & Alertas',
                  'date': '2026-11-18',
                  'compressed': false,
                  'sizeBytes': 4096,
                  'lastModified': '2026-11-18T11:55:00Z',
                },
                {
                  'fileName': 'security-audit-2026-11-17.0.log.gz',
                  'channel': 'security-audit',
                  'label': 'Segurança & Auditoria',
                  'date': '2026-11-17',
                  'compressed': true,
                  'sizeBytes': 3072,
                  'lastModified': '2026-11-17T23:59:00Z',
                },
              ],
            });
          }

          if (options.path == '/api/admin/logs/files/application.log') {
            return _jsonResponse({
              'fileName': 'application.log',
              'channel': 'application',
              'sizeBytes': 8192,
              'retentionDays': 30,
              'totalLines': 2,
              'matchedLines': 2,
              'infoCount': 1,
              'warnCount': 1,
              'errorCount': 1,
              'page': 0,
              'limit': 80,
              'entries': [
                {
                  'lineNumber': 2,
                  'timestamp': '2026-11-18T12:00:01.100Z',
                  'level': 'WARN',
                  'thread': 'http-nio-8080',
                  'correlationId': 'corr-abc-123',
                  'logger': 'c.d.i.p.AuthService',
                  'message': 'Tentativa de token expirado detectada',
                  'rawLine': 'WARN Tentativa de token expirado',
                },
                {
                  'lineNumber': 1,
                  'timestamp': '2026-11-18T11:59:00.000Z',
                  'level': 'INFO',
                  'thread': 'main',
                  'correlationId': 'NO_CORR_ID',
                  'logger': 'c.d.i.p.ProjApplication',
                  'message': 'Servidor backend iniciado',
                  'rawLine': 'INFO Servidor backend iniciado',
                },
              ],
            });
          }

          if (options.path == '/api/admin/logs/files/errors.log') {
            return _jsonResponse({
              'fileName': 'errors.log',
              'channel': 'errors',
              'sizeBytes': 4096,
              'retentionDays': 30,
              'totalLines': 1,
              'matchedLines': 1,
              'infoCount': 0,
              'warnCount': 0,
              'errorCount': 1,
              'page': 0,
              'limit': 80,
              'entries': [
                {
                  'lineNumber': 10,
                  'timestamp': '2026-11-18T11:55:00.000Z',
                  'level': 'ERROR',
                  'thread': 'worker-1',
                  'correlationId': 'corr-err-9',
                  'logger': 'c.d.i.p.GlobalExceptionHandler',
                  'message': 'Falha isolada tratada',
                  'rawLine': 'ERROR Falha isolada tratada',
                },
              ],
            });
          }

          if (options.path == '/api/admin/logs' && options.method == 'GET') {
            return _jsonResponse({
              'content': [
                {
                  'id': 1,
                  'timestamp': '2026-11-18T12:00:00',
                  'category': 'AUTH',
                  'severity': 'INFO',
                  'action': 'LOGIN_SUCCESS',
                  'actorEmail': 'admin@duolingo.com',
                  'actorRole': 'ADMIN',
                  'result': 'SUCCESS',
                },
              ],
              'totalElements': 1,
              'totalPages': 1,
              'currentPage': 0,
              'pageSize': 15,
            });
          }

          return _jsonResponse({}, statusCode: 404);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminAuditLogsView(dio: dio),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Central de Logs & Auditoria'), findsOneWidget);
        expect(find.text('Retenção: 30 dias'), findsOneWidget);
        expect(find.text('3 arquivo(s)'), findsOneWidget);
        expect(find.text('15.0 KB'), findsOneWidget);
        expect(find.text('application.log'), findsWidgets);
        expect(find.text('errors.log'), findsOneWidget);
        expect(find.text('security-audit-2026-11-17.0.log.gz'), findsOneWidget);
        expect(find.text('Tentativa de token expirado detectada'), findsOneWidget);
        expect(find.text('corr-abc-123'), findsOneWidget);

        // Seleciona errors.log para visualizar canal separado
        await tester.tap(find.text('errors.log'));
        await tester.pumpAndSettle();
        expect(find.text('Falha isolada tratada'), findsOneWidget);

        // Alterna para aba Auditoria Estruturada
        await tester.tap(find.text('Auditoria Estruturada'));
        await tester.pumpAndSettle();
        expect(find.text('LOGIN_SUCCESS'), findsOneWidget);
      },
    );

    testWidgets(
      'PersonalizedLearningPathView exibe apenas idiomas aprendidos, normaliza RadarChart 0..100 e muda dados por idioma',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final requestedLangs = <String>[];
        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          if (options.uri.path.endsWith('/api/learning-path/me')) {
            final lang =
                options.queryParameters['language']?.toString() ?? 'Japonês';
            requestedLangs.add(lang);
            final isJapanese = lang == 'Japonês';
            return _jsonResponse({
              'id': isJapanese ? 11 : 12,
              'studentId': 77,
              'language': lang,
              'availableLanguages': ['Japonês', 'Espanhol'],
              'currentCefrLevel': isJapanese ? 'B1' : 'A1',
              'targetCefrLevel': 'B2',
              'dailyGoalMinutes': 15,
              'currentStreakDays': isJapanese ? 6 : 1,
              'overallProgressPercent': isJapanese ? 50.0 : 0.0,
              'grammarCompetence': isJapanese ? 72.0 : 12.0,
              'vocabularyCompetence': isJapanese ? 84.0 : 18.0,
              'listeningCompetence': isJapanese ? 60.0 : 8.0,
              'speakingCompetence': isJapanese ? 55.0 : 6.0,
              'readingCompetence': isJapanese ? 78.0 : 14.0,
              'writingCompetence': isJapanese ? 66.0 : 10.0,
              'activityMetrics': {
                'languageXp': isJapanese ? 250 : 20,
                'modulesCompleted': isJapanese ? 4 : 0,
                'modulesTotal': 8,
                'exerciseSubmissions': isJapanese ? 3 : 0,
                'srsReviewed': isJapanese ? 12 : 0,
                'pronunciationAttempts': isJapanese ? 4 : 0,
                'aiConversationTurns': isJapanese ? 5 : 0,
              },
              'modules': [
                {
                  'moduleId': isJapanese ? 601 : 701,
                  'language': lang,
                  'cefrLevel': 'A1',
                  'moduleOrder': 1,
                  'title': 'Módulo Inicial ($lang)',
                  'description': 'Conteúdo em $lang',
                  'category': 'Fundamentos',
                  'status': isJapanese ? 'COMPLETED' : 'IN_PROGRESS',
                  'requiredXp': 40,
                },
              ],
            });
          }
          return _jsonResponse(const {});
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PersonalizedLearningPathView(
                onBack: () {},
                dio: dio,
                initialLanguage: 'Inglês',
                enrolledLanguages: const ['Japonês', 'Espanhol'],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Apenas os idiomas do aluno aparecem (Inglês/Francês/Alemão/Italiano NÃO aparecem)
        expect(find.text('Japonês'), findsOneWidget);
        expect(find.text('Espanhol'), findsOneWidget);
        expect(find.text('Inglês'), findsNothing);
        expect(find.text('Francês'), findsNothing);
        expect(find.text('Alemão'), findsNothing);
        expect(find.text('Italiano'), findsNothing);

        // Radar normalized 0..100 (floor + ceiling + data = 3 datasets) and Japanese stats shown
        final radar = tester.widget<RadarChart>(find.byType(RadarChart));
        expect(radar.data.dataSets.length, 3);
        expect(find.text('250 XP em Japonês'), findsOneWidget);
        expect(find.text('Revisões SRS: 12'), findsOneWidget);
        expect(find.text('Média em Japonês: 69%'), findsOneWidget);
        expect(find.text('Módulo Inicial (Japonês)'), findsOneWidget);

        // Alternar para Espanhol recarrega dados reais deste outro idioma
        await tester.tap(find.text('Espanhol'));
        await tester.pumpAndSettle();

        expect(requestedLangs.contains('Espanhol'), isTrue);
        expect(find.text('20 XP em Espanhol'), findsOneWidget);
        expect(find.text('Revisões SRS: 0'), findsOneWidget);
        expect(find.text('Média em Espanhol: 11%'), findsOneWidget);
        expect(find.text('Módulo Inicial (Espanhol)'), findsOneWidget);
      },
    );

    testWidgets(
      'EntityPicturePickerDialog envia PUT para atualizar foto da instituição ou turma',
      (tester) async {
        String? capturedPath;
        dynamic capturedBody;
        final dio = Dio();
        dio.httpClientAdapter = _JsonHttpAdapter((options) {
          capturedPath = options.uri.path;
          capturedBody = options.data;
          return _jsonResponse({
            'id': 42,
            'name': 'Instituto Teste',
            'pictureUrl': 'https://cdn.example.com/brasao.png',
          });
        });

        String? savedCallbackValue;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      EntityPicturePickerDialog.show(
                        ctx,
                        title: 'Foto da Instituição',
                        entityName: 'Instituto Teste',
                        endpointPath: '/api/institutions/42/picture',
                        dio: dio,
                        onSaved: (v) => savedCallbackValue = v,
                      );
                    },
                    child: const Text('Abrir Foto'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Foto'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).last,
          'https://cdn.example.com/brasao.png',
        );
        await tester.tap(find.text('Salvar Foto'));
        await tester.pumpAndSettle();

        expect(capturedPath, '/api/institutions/42/picture');
        expect(capturedBody, {'pictureUrl': 'https://cdn.example.com/brasao.png'});
        expect(savedCallbackValue, 'https://cdn.example.com/brasao.png');
      },
    );
  });
}
