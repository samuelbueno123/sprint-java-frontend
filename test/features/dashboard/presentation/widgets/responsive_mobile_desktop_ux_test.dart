import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:frontend/features/dashboard/domain/entities/student_profile.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/presentation/widgets/dashboard_shell.dart';
import 'package:frontend/features/dashboard/presentation/widgets/responsive_layout.dart';

void main() {
  const dummyStudentProfile = StudentProfile(
    id: 1,
    googleId: 'g-1',
    name: 'Carlos Mendes',
    email: 'carlos@escola.com',
    languages: ['Inglês', 'Espanhol'],
  );

  const studentData = DashboardData(
    user: DashboardUser(
      id: 'student-1',
      googleId: 'g-1',
      email: 'carlos@escola.com',
      name: 'Carlos Mendes',
    ),
    profileType: UserProfileType.student,
    profileCompleted: true,
    studentProfile: dummyStudentProfile,
  );

  testWidgets(
    'DashboardShell renders bottom navigation on mobile screen width',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String activeSection = 'profile';

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardShell(
            data: studentData,
            activeSection: activeSection,
            onSectionSelected: (sec) => activeSection = sec,
            onLogout: () {},
            onRefresh: () {},
            onProfileTypeSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify NavigationBar is present on mobile
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Início'), findsWidgets);
      expect(find.text('Turmas'), findsWidgets);
      expect(find.text('Vocabulário'), findsWidgets);
    },
  );

  testWidgets(
    'DashboardShell hides bottom navigation on desktop screen width',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardShell(
            data: studentData,
            activeSection: 'profile',
            onSectionSelected: (_) {},
            onLogout: () {},
            onRefresh: () {},
            onProfileTypeSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // NavigationBar must NOT exist on desktop
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets(
    'AppModernBadge and AppModernCard render properly with semantic colors',
    (tester) async {
      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: AppModernCard(
              title: 'Resumo de Aprendizado',
              subtitle: 'Visão geral do aluno',
              leadingIcon: Icons.auto_awesome,
              trailing: const AppModernBadge(
                label: 'Nível B1',
                variant: AppBadgeVariant.success,
              ),
              child: const Text('Conteúdo do cartão'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resumo de Aprendizado'), findsOneWidget);
      expect(find.text('Visão geral do aluno'), findsOneWidget);
      expect(find.text('Nível B1'), findsOneWidget);
      expect(find.text('Conteúdo do cartão'), findsOneWidget);
    },
  );
}
