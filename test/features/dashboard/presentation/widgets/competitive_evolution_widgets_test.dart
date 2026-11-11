import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:frontend/features/dashboard/domain/entities/teacher_class_assignment.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/presentation/widgets/dashboard_sidebar.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/student_mistakes_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/student_vocabulary_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/teacher_class_analytics_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/class_announcements_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/student_notifications_dialog.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/teacher_student_notes_dialog.dart';

void main() {
  testWidgets(
    'DashboardSidebar renders competitive evolution items for students',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? selectedSection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardSidebar(
              profileType: UserProfileType.student,
              activeSection: 'profile',
              onSectionSelected: (s) => selectedSection = s,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Caderno de Erros'), findsOneWidget);
      expect(find.text('Meu Vocabulário'), findsOneWidget);

      await tester.tap(find.text('Caderno de Erros'));
      expect(selectedSection, equals('mistakes'));

      await tester.tap(find.text('Meu Vocabulário'));
      expect(selectedSection, equals('vocabulary'));
    },
  );

  testWidgets('DashboardSidebar renders Analytics da Turma for teachers', (
    tester,
  ) async {
    String? selectedSection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardSidebar(
            profileType: UserProfileType.teacher,
            activeSection: 'teacherClasses',
            onSectionSelected: (s) => selectedSection = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Analytics da Turma'), findsOneWidget);
    await tester.tap(find.text('Analytics da Turma'));
    expect(selectedSection, equals('classAnalytics'));
  });

  testWidgets('StudentMistakesView renders gracefully', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StudentMistakesView(onBack: () {})),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(StudentMistakesView), findsOneWidget);
      expect(find.text('Caderno de Erros Inteligente'), findsOneWidget);
    });
  });

  testWidgets('StudentVocabularyView renders gracefully', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StudentVocabularyView(onBack: () {})),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(StudentVocabularyView), findsOneWidget);
      expect(find.text('Meu Vocabulário (Cofre Pessoal)'), findsOneWidget);
    });
  });

  testWidgets(
    'TeacherClassAnalyticsView renders gracefully with active assignments',
    (tester) async {
      const dummyData = DashboardData(
        user: DashboardUser(
          id: 'teacher-1',
          googleId: 'g-1',
          email: 'prof@escola.com',
          name: 'Professora Ana',
        ),
        profileType: UserProfileType.teacher,
        profileCompleted: true,
        teacherAssignments: [
          TeacherClassAssignment(
            id: 1,
            schoolClassId: 10,
            schoolClassName: 'Inglês Instrumental 1º Ano A',
            startDate: '2026-02-01',
            endDate: null,
            reason: null,
          ),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherClassAnalyticsView(data: dummyData, onBack: () {}),
            ),
          ),
        );
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.byType(TeacherClassAnalyticsView), findsOneWidget);
        expect(find.text('Analytics Pedagógico da Turma'), findsOneWidget);
      });
    },
  );

  testWidgets('ClassAnnouncementsView renders correctly for students', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClassAnnouncementsView(
              classId: 10,
              className: 'Turma Francês A1',
              isTeacher: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(ClassAnnouncementsView), findsOneWidget);
      expect(find.text('Mural de Avisos: Turma Francês A1'), findsOneWidget);
    });
  });

  testWidgets(
    'StudentNotificationsDialog displays notification center dialog',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => StudentNotificationsDialog.show(ctx),
                  child: const Text('Abrir Notificações'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Abrir Notificações'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.byType(StudentNotificationsDialog), findsOneWidget);
        expect(find.text('Central de Notificações'), findsOneWidget);
      });
    },
  );

  testWidgets('TeacherStudentNotesDialog displays confidential notes dialog', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TeacherStudentNotesDialog.show(
                  ctx,
                  studentId: 42,
                  studentName: 'Lucas Oliveira',
                  classId: 10,
                ),
                child: const Text('Abrir Notas'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Abrir Notas'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(TeacherStudentNotesDialog), findsOneWidget);
      expect(find.text('Anotações Privadas: Lucas Oliveira'), findsOneWidget);
    });
  });
}
