import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:frontend/features/dashboard/domain/entities/teacher_class_assignment.dart';
import 'package:frontend/features/dashboard/domain/entities/teacher_profile.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/presentation/widgets/teacher_dashboard_view.dart';

void main() {
  const teacherProfile = TeacherProfile(
    id: 1,
    googleId: 'g-teacher-1',
    name: 'Ana Silva',
    email: 'ana@duolinfo.com',
    institution: 'CEFET-RJ',
    institutionId: 1,
    taughtLanguages: ['Inglês', 'Francês'],
    specializationAreas: ['Conversação', 'Fonética'],
    bibliography: 'Doutora em Linguística',
  );

  const teacherData = DashboardData(
    user: DashboardUser(
      googleId: 'g-teacher-1',
      email: 'ana@duolinfo.com',
      name: 'Ana Silva',
    ),
    profileType: UserProfileType.teacher,
    profileCompleted: true,
    teacherProfile: teacherProfile,
    teacherAssignments: [
      TeacherClassAssignment(
        id: 10,
        schoolClassId: 2,
        schoolClassName: 'Turma Francês A1',
        startDate: '2026-02-01',
        endDate: null,
        reason: 'Docente titular',
      ),
    ],
  );

  testWidgets(
    'renders teacher dashboard home with stats, institution, and languages',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeacherDashboardView(
              data: teacherData,
              activeSection: 'home',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Olá, Ana!'), findsOneWidget);
      expect(find.text('CEFET-RJ'), findsWidgets);
      expect(find.text('Idiomas de Ensino'), findsOneWidget);
      expect(find.text('Especializações'), findsWidgets);
      expect(find.text('Turmas Atribuídas'), findsOneWidget);
      expect(find.text('Inglês'), findsWidgets);
      expect(find.text('Francês'), findsWidgets);
    },
  );

  testWidgets('renders languages section with academic details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TeacherDashboardView(
            data: teacherData,
            activeSection: 'languages',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ensino e idiomas'), findsOneWidget);
    expect(find.text('Idiomas Lecionados'), findsOneWidget);
    expect(find.text('Orientações Didáticas'), findsOneWidget);
  });

  testWidgets('renders fallback when teacher profile is missing', (
    tester,
  ) async {
    const dataWithoutTeacher = DashboardData(
      user: DashboardUser(
        googleId: 'g-user',
        email: 'user@duolinfo.com',
        name: 'Sem Perfil',
      ),
      profileType: UserProfileType.teacher,
      profileCompleted: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TeacherDashboardView(
            data: dataWithoutTeacher,
            activeSection: 'home',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Dados do perfil docente não encontrados'),
      findsOneWidget,
    );
  });
}
