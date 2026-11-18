import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/ui/in_app_file_viewer.dart';
import 'package:frontend/core/ui/language_flag.dart';
import 'package:frontend/core/ui/motion_kit.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/presentation/widgets/admin/admin_audit_logs_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/admin/admin_catalog_management_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/admin/admin_system_health_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/admin/admin_teacher_documents_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/dashboard_sidebar.dart';

class _CatalogMockAdapter implements HttpClientAdapter {
  _CatalogMockAdapter(this._handler);

  final ResponseBody Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

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

        expect(find.text('Performance & FLChart'), findsOneWidget);
        expect(find.text('Logs & Auditoria'), findsOneWidget);
        expect(find.text('Monitoramento & Saúde'), findsOneWidget);
        expect(find.text('Catálogo & Idiomas'), findsOneWidget);
        expect(find.text('Documentos Docentes'), findsOneWidget);

        Future<void> tapNavItem(String label) async {
          final finder = find.text(label);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
        }

        await tapNavItem('Performance & FLChart');
        expect(selectedSection, equals('systemPerformance'));

        await tapNavItem('Logs & Auditoria');
        expect(selectedSection, equals('auditLogs'));

        await tapNavItem('Monitoramento & Saúde');
        expect(selectedSection, equals('systemHealth'));

        await tapNavItem('Catálogo & Idiomas');
        expect(selectedSection, equals('catalogManagement'));

        await tapNavItem('Documentos Docentes');
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

    testWidgets(
      'AdminSystemHealthView renders FLChart LineChart, PieChart, BarChart and radial gauges without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final payload = <String, dynamic>{
          'status': 'UP',
          'database': <String, dynamic>{
            'status': 'UP',
            'pingMs': 1.2,
            'poolName': 'DuolinfoHikariPool',
            'activeConnections': 3,
            'idleConnections': 5,
            'totalConnections': 8,
            'maximumPoolSize': 25,
            'threadsAwaitingConnection': 0,
          },
          'systemResources': <String, dynamic>{
            'jvmMaxMemoryMb': 5920,
            'jvmUsedMemoryMb': 110,
            'jvmFreeMemoryMb': 106,
            'memoryUsedPercent': 1.9,
            'availableProcessors': 28,
            'logicalProcessors': 28,
            'systemCpuPercent': 14.5,
            'processCpuPercent': 1.2,
            'jvmActiveThreads': 29,
            'hostMemoryUsedPercent': 48.0,
            'uptimeSeconds': 2106,
          },
          'externalAi': <String, dynamic>{
            'status': 'UP',
            'service': 'Google Gemini AI',
            'model': 'gemini-2.5-flash',
            'providerUrl': 'https://generativelanguage.googleapis.com',
          },
          'application': <String, dynamic>{
            'applicationName': 'Duolinfo Backend',
            'javaVersion': '17.0.21',
            'springBootVersion': '4.1.1',
            'currentTime': '2026-11-18T03:37:55',
          },
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminSystemHealthView(healthLoader: () async => payload),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Curva de Saúde em Tempo Real (%)'), findsOneWidget);
        expect(find.text('Capacidade do Pool Hikari'), findsOneWidget);
        expect(
          find.text('Comparativo Instantâneo de Utilização por Subsistema (%)'),
          findsOneWidget,
        );
        expect(find.byType(LineChart), findsOneWidget);
        expect(find.byType(PieChart), findsOneWidget);
        expect(find.byType(BarChart), findsOneWidget);
        expect(find.byType(AnimatedRadialGauge), findsNWidgets(2));
        expect(find.text('28 vCPUs'), findsOneWidget);
        expect(find.text('29 ativas'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminCatalogManagementView handles lowercase language type, renders flags, and creates language with auto or manual flag',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final capturedPosts = <Map<String, dynamic>>[];
        final dio = Dio();
        dio.httpClientAdapter = _CatalogMockAdapter((options) {
          if (options.path == '/api/admin/catalog' && options.method == 'GET') {
            return ResponseBody.fromString(
              jsonEncode([
                {
                  'id': 1,
                  'catalogType': 'language',
                  'value': 'Inglês',
                  'active': true,
                  'flagMode': 'AUTO',
                  'flagCode': 'us',
                },
                {
                  'id': 2,
                  'catalogType': 'language',
                  'value': 'Japonês',
                  'active': true,
                  'flagMode': 'AUTO',
                  'flagCode': 'jp',
                },
                {
                  'id': 9,
                  'catalogType': 'proficiency',
                  'value': 'Difícil',
                  'active': true,
                },
              ]),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json; charset=utf-8'],
              },
            );
          }
          if (options.path == '/api/admin/catalog' &&
              options.method == 'POST') {
            final body = Map<String, dynamic>.from(options.data as Map);
            capturedPosts.add(body);
            return ResponseBody.fromString(
              jsonEncode({
                'id': 50,
                'catalogType': 'language',
                'value': body['value'],
                'active': body['active'] ?? true,
                'flagMode': body['flagMode'] ?? 'AUTO',
                'flagCode': body['flagCode'] ?? 'kr',
                'flagUrl': body['flagUrl'],
              }),
              201,
              headers: {
                Headers.contentTypeHeader: ['application/json; charset=utf-8'],
              },
            );
          }
          return ResponseBody.fromString('{}', 404);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AdminCatalogManagementView(dio: dio)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.byType(LanguageFlag), findsNWidgets(2));
        expect(find.text('Idioma'), findsNWidgets(2));
        expect(find.text('Proficiência'), findsOneWidget);
        expect(find.text('Bandeira Auto · US'), findsOneWidget);
        expect(find.text('Bandeira Auto · JP'), findsOneWidget);

        // Abre modal para adicionar novo idioma com bandeira automática e manual
        await tester.tap(find.text('Nova Opção'));
        await tester.pumpAndSettle();

        expect(find.text('Nova Opção de Catálogo'), findsOneWidget);
        expect(find.text('Automática'), findsOneWidget);
        expect(find.text('Manual (Admin)'), findsOneWidget);

        // Digita "Coreano" no modo automático -> detecta KR automaticamente
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ).first,
          'Coreano',
        );
        await tester.pumpAndSettle();
        expect(find.text('Código detectado: KR'), findsOneWidget);

        // Alterna para Manual e seleciona Portugal (PT)
        await tester.tap(find.text('Manual (Admin)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Portugal (PT)'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Salvar Opção'));
        await tester.pumpAndSettle();

        expect(capturedPosts, hasLength(1));
        expect(capturedPosts.first['catalogType'], 'LANGUAGE');
        expect(capturedPosts.first['value'], 'Coreano');
        expect(capturedPosts.first['flagMode'], 'MANUAL');
        expect(capturedPosts.first['flagCode'], 'pt');
        expect(find.text('Coreano'), findsOneWidget);
        expect(find.text('Bandeira Manual · PT'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminTeacherDocumentsView opens text, PDF and image files inside InAppFileViewerDialog',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dio = Dio();
        dio.httpClientAdapter = _CatalogMockAdapter((options) {
          if (options.path == '/api/admin/documents') {
            return ResponseBody.fromString(
              jsonEncode({
                'content': [
                  {
                    'id': 11,
                    'fileName': 'certificado-letras.txt',
                    'contentType': 'text/plain',
                    'fileSize': 44,
                    'teacherId': 3,
                    'teacherName': 'Prof. Carlos',
                    'teacherEmail': 'carlos@escola.local',
                    'institutionName': 'CEFET/RJ',
                  },
                  {
                    'id': 12,
                    'fileName': 'diploma-uf.pdf',
                    'contentType': 'application/pdf',
                    'fileSize': 128,
                    'teacherId': 3,
                    'teacherName': 'Prof. Carlos',
                    'teacherEmail': 'carlos@escola.local',
                    'institutionName': 'CEFET/RJ',
                  },
                ],
                'number': 0,
                'totalPages': 1,
                'totalElements': 2,
              }),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json; charset=utf-8'],
              },
            );
          }

          if (options.path == '/api/admin/documents/11/download') {
            return ResponseBody.fromBytes(
              utf8.encode(
                'Certificado Oficial de Proficiência\nNivelamento: C1 Inglês',
              ),
              200,
              headers: {
                Headers.contentTypeHeader: ['text/plain'],
              },
            );
          }

          if (options.path == '/api/admin/documents/12/download') {
            return ResponseBody.fromBytes(
              utf8.encode('%PDF-1.7\n1 0 obj << /Type /Page >>\n%%EOF'),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/pdf'],
              },
            );
          }

          return ResponseBody.fromString('{}', 404);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AdminTeacherDocumentsView(dio: dio)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Abrir Arquivo Local'), findsOneWidget);
        expect(find.text('certificado-letras.txt'), findsOneWidget);
        expect(find.text('Abrir no App'), findsNWidgets(2));

        // Abre documento texto no visualizador interno e filtra conteúdo
        await tester.tap(find.text('Abrir no App').first);
        await tester.pumpAndSettle();

        expect(find.byType(InAppFileViewerDialog), findsOneWidget);
        expect(find.textContaining('Certificado Oficial'), findsOneWidget);

        await tester.tap(find.byTooltip('Fechar visualizador'));
        await tester.pumpAndSettle();

        // Abre PDF no visualizador interno
        await tester.tap(find.text('Abrir no App').last);
        await tester.pumpAndSettle();
        expect(find.byType(InAppFileViewerDialog), findsOneWidget);
        expect(find.textContaining('PDF'), findsWidgets);
      },
    );
  });
}
