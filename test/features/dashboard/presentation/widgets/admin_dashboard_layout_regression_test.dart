import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/presentation/widgets/admin_dashboard_view.dart';

void main() {
  const adminData = DashboardData(
    user: DashboardUser(
      id: '1',
      googleId: '',
      email: 'admin@duolingo.com',
      name: 'Administrador Duolinfo',
      isAdmin: true,
      isSuperAdmin: true,
    ),
    profileType: UserProfileType.admin,
    availableProfileTypes: [UserProfileType.admin],
    profileCompleted: true,
  );

  for (final size in const [Size(1280, 900), Size(390, 844)]) {
    testWidgets(
      'AdminDashboardView profile overview renders without layout errors at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final capturedErrors = <FlutterErrorDetails>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          capturedErrors.add(details);
        };
        try {
          await tester.runAsync(() async {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: AdminDashboardView(
                    data: adminData,
                    activeSection: 'profile',
                    onSectionSelected: (_) {},
                    onLogout: () {},
                    onRefresh: () {},
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 100));
          });
        } finally {
          FlutterError.onError = prevOnError;
        }

        if (capturedErrors.isNotEmpty) {
          fail(capturedErrors.map((e) => e.toString()).join('\n\n'));
        }
        expect(tester.takeException(), isNull);
        expect(find.text('Administrador Duolinfo'), findsOneWidget);
        expect(find.text('admin@duolingo.com'), findsOneWidget);
        expect(find.text('Cadastros Rápidos'), findsOneWidget);
        expect(find.text('Banco de Dados'), findsOneWidget);
      },
    );
  }
}
