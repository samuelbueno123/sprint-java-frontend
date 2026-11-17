import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/ui/mascot/mascot.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:frontend/features/dashboard/domain/entities/student_profile.dart';
import 'package:frontend/features/dashboard/domain/entities/teacher_class_assignment.dart';
import 'package:frontend/features/dashboard/domain/entities/teacher_profile.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/presentation/widgets/student_settings_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/teacher_exercise_preview_screen.dart';
import 'package:frontend/features/dashboard/presentation/widgets/teacher_exercises_overview_screen.dart';
import 'package:frontend/features/dashboard/presentation/widgets/teacher_settings_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/user_settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OverviewMockAdapter implements HttpClientAdapter {
  _OverviewMockAdapter({required this.onPut});

  final void Function(String path, Map<String, dynamic> body) onPut;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' &&
        options.path.startsWith('/api/students/class/')) {
      return ResponseBody.fromString(
        jsonEncode(const []),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.method == 'PUT' && options.path.startsWith('/api/exercises/')) {
      final body = Map<String, dynamic>.from(options.data as Map);
      onPut(options.path, body);
      return ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{}',
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const studentData = DashboardData(
    user: DashboardUser(
      googleId: 'g-stu',
      email: 'stu@duolinfo.com',
      name: 'Lucas Aluno',
    ),
    profileType: UserProfileType.student,
    profileCompleted: true,
    studentProfile: StudentProfile(
      id: 1,
      googleId: 'g-stu',
      name: 'Lucas Aluno',
      email: 'stu@duolinfo.com',
      languages: ['Inglês'],
    ),
  );

  const teacherData = DashboardData(
    user: DashboardUser(
      googleId: 'g-prof',
      email: 'prof@duolinfo.com',
      name: 'Carla Prof',
    ),
    profileType: UserProfileType.teacher,
    profileCompleted: true,
    teacherProfile: TeacherProfile(
      id: 2,
      googleId: 'g-prof',
      name: 'Carla Prof',
      email: 'prof@duolinfo.com',
      institution: 'IFRJ',
      institutionId: 1,
      taughtLanguages: ['Inglês'],
      specializationAreas: ['Gramática'],
    ),
    teacherAssignments: [
      TeacherClassAssignment(
        id: 10,
        schoolClassId: 5,
        schoolClassName: 'Turma Inglês B1',
        startDate: '2026-02-01',
        endDate: null,
        reason: 'Docente',
      ),
    ],
  );

  const userData = DashboardData(
    user: DashboardUser(
      googleId: 'g-admin',
      email: 'admin@duolinfo.com',
      name: 'Gestor',
    ),
    profileType: UserProfileType.admin,
    profileCompleted: true,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MascotController.instance.resetForTest();
    await MascotPreferenceController.setVariant(MascotVariant.white);
    await MascotPreferenceController.setAnimationsEnabled(true);
  });

  tearDown(() {
    MascotController.instance.resetForTest();
  });

  group('Settings views embed MascotSettingsCard', () {
    testWidgets(
      'StudentSettingsView, TeacherSettingsView, and UserSettingsView render MascotSettingsCard',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1100, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: StudentSettingsView(
                  data: studentData,
                  onBackToProfile: () {},
                  onLogout: () {},
                ),
              ),
            ),
          );
          await tester.pump();
        });
        await tester.scrollUntilVisible(
          find.byType(MascotSettingsCard),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(MascotSettingsCard), findsOneWidget);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              home: Scaffold(
                body: TeacherSettingsView(
                  data: teacherData,
                  onBackToProfile: () {},
                  onLogout: () {},
                ),
              ),
            ),
          );
          await tester.pump();
        });
        await tester.scrollUntilVisible(
          find.byType(MascotSettingsCard),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(MascotSettingsCard), findsOneWidget);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              home: Scaffold(
                body: UserSettingsView(
                  data: userData,
                  onBackToProfile: () {},
                  onLogout: () {},
                ),
              ),
            ),
          );
          await tester.pump();
        });
        await tester.scrollUntilVisible(
          find.byType(MascotSettingsCard),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(MascotSettingsCard), findsOneWidget);
      },
    );
  });

  group('Teacher preview & overview mascotHelpMessage flows', () {
    testWidgets(
      'TeacherExercisePreviewScreen displays mascotHelpMessage and syncs controller',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 820));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: TeacherExercisePreviewScreen(
              title: 'Present Perfect',
              category: 'Gramática',
              theme: 'Experiências',
              level: 'B1',
              mascotHelpMessage: 'Observe o uso de have/has + particípio.',
              questions: [
                {
                  'question': 'She ___ visited London twice.',
                  'style': 'Múltipla escolha',
                  'options': ['have', 'has', 'did'],
                  'correctAnswer': 'has',
                },
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dica configurada no Bode Branco'), findsOneWidget);
        expect(
          find.text('Observe o uso de have/has + particípio.'),
          findsOneWidget,
        );
        expect(
          MascotController.instance.currentActivity?.mascotHelpMessage,
          'Observe o uso de have/has + particípio.',
        );

        // Disposing preview removes its activity token cleanly
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pump();
        expect(MascotController.instance.isInActivity, isFalse);
      },
    );

    testWidgets(
      'TeacherExercisesOverviewScreen Editar dialog submits PUT /api/exercises/{id} with mascotHelpMessage',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1100, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String? capturedPath;
        Map<String, dynamic>? capturedBody;

        final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
        dio.httpClientAdapter = _OverviewMockAdapter(
          onPut: (path, body) {
            capturedPath = path;
            capturedBody = body;
          },
        );

        var refreshed = false;
        final exercises = [
          {
            'id': 42,
            'title': 'Past Simple vs Present Perfect',
            'category': 'Gramática',
            'theme': 'Tempos Verbais',
            'languageName': 'Inglês',
            'proficiencyLevel': 'B1',
            'schoolClassId': 5,
            'schoolClassName': 'Turma Inglês B1',
            'description': 'Prática guiada',
            'mascotHelpMessage': 'Dica antiga',
            'questions': [
              {
                'style': 'Múltipla escolha',
                'question': 'Yesterday I ___ to work.',
                'options': ['go', 'went'],
                'correctAnswer': 'went',
              },
            ],
          },
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherExercisesOverviewScreen(
                data: teacherData,
                exercises: exercises,
                submissions: const [],
                dio: dio,
                onCreateExercise: () {},
                onRefresh: () => refreshed = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expand the package card to expose the Editar button
        await tester.tap(find.text('Tempos Verbais'));
        await tester.pumpAndSettle();

        expect(find.text('Dica do Bode'), findsOneWidget);
        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();

        expect(find.text('Editar Atividade'), findsOneWidget);
        final helpField = find.widgetWithText(
          TextField,
          'Dica do Bode Branco (opcional)',
        );
        expect(helpField, findsOneWidget);

        await tester.enterText(helpField, 'Foque no advérbio Yesterday!');
        await tester.tap(find.text('Salvar Alterações'));
        await tester.pumpAndSettle();

        expect(capturedPath, '/api/exercises/42');
        expect(capturedBody, isNotNull);
        expect(
          capturedBody!['mascotHelpMessage'],
          'Foque no advérbio Yesterday!',
        );
        expect(capturedBody!['title'], 'Past Simple vs Present Perfect');
        expect(refreshed, isTrue);
      },
    );
  });
}
