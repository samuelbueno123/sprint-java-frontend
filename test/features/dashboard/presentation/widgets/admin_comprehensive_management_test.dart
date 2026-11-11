import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/presentation/widgets/admin/admin_audit_logs_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/admin/admin_catalog_management_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/admin/admin_system_health_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/admin/admin_teacher_documents_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/dashboard_sidebar.dart';

void main() {
  group('Admin Comprehensive Management UI Tests', () {
    testWidgets(
      'DashboardSidebar renders all 4 administrative management nav items for admin',
      (tester) async {
        String? selectedSection;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardSidebar(
                profileType: UserProfileType.admin,
                activeSection: 'profile',
                isSuperAdmin: true,
                onSectionSelected: (s) => selectedSection = s,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Logs & Auditoria'), findsOneWidget);
        expect(find.text('Monitoramento & Saúde'), findsOneWidget);
        expect(find.text('Catálogo & Idiomas'), findsOneWidget);
        expect(find.text('Documentos Docentes'), findsOneWidget);

        await tester.tap(find.text('Logs & Auditoria'));
        expect(selectedSection, equals('auditLogs'));

        await tester.tap(find.text('Monitoramento & Saúde'));
        expect(selectedSection, equals('systemHealth'));

        await tester.tap(find.text('Catálogo & Idiomas'));
        expect(selectedSection, equals('catalogManagement'));

        await tester.tap(find.text('Documentos Docentes'));
        expect(selectedSection, equals('teacherDocuments'));
      },
    );

    testWidgets('AdminAuditLogsView renders header and filter chips', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AdminAuditLogsView())),
        );
        await tester.pump();

        expect(find.text('Central de Logs & Auditoria'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });
    });

    testWidgets('AdminSystemHealthView renders title and auto-refresh switch', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AdminSystemHealthView())),
        );
        await tester.pump();

        expect(find.text('Monitoramento & Diagnóstico'), findsOneWidget);
        expect(find.text('Auto (10s):'), findsOneWidget);
        expect(find.byType(Switch), findsOneWidget);
      });
    });

    testWidgets(
      'AdminCatalogManagementView renders header, stat cards and new option button',
      (tester) async {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: AdminCatalogManagementView()),
            ),
          );
          await tester.pump();

          expect(find.text('Catálogo & Idiomas Oficiais'), findsOneWidget);
          expect(find.text('Nova Opção'), findsOneWidget);
          expect(find.text('Total de Itens'), findsOneWidget);
        });
      },
    );

    testWidgets('AdminTeacherDocumentsView renders header and search input', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AdminTeacherDocumentsView())),
        );
        await tester.pump();

        expect(find.text('Documentos & Diplomas Docentes'), findsOneWidget);
        expect(find.text('Buscar'), findsOneWidget);
        expect(find.text('Total de Comprovações'), findsOneWidget);
      });
    });
  });
}
