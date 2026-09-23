import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:frontend/features/dashboard/domain/entities/student_profile.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/presentation/widgets/student_dashboard_view.dart';

void main() {
  testWidgets('renders student dashboard with student name and languages', (
    tester,
  ) async {
    const studentProfile = StudentProfile(
      id: 1,
      googleId: '123',
      name: 'Maria Silva',
      email: 'maria@duolinfo.com',
      languages: ['Inglês'],
    );

    const data = DashboardData(
      user: DashboardUser(
        googleId: '123',
        email: 'maria@duolinfo.com',
        name: 'Maria Silva',
      ),
      profileType: UserProfileType.student,
      profileCompleted: true,
      studentProfile: studentProfile,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StudentDashboardView(data: data, activeSection: 'home'),
        ),
      ),
    );

    expect(find.textContaining('Olá, Maria!'), findsOneWidget);
    expect(find.text('Inglês'), findsOneWidget);
    expect(find.text('Nível B2'), findsNothing);
    expect(find.textContaining('XP'), findsNothing);
  });
}
