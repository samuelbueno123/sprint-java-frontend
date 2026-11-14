import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/supported_languages.dart';
import 'package:frontend/features/dashboard/presentation/widgets/admin/admin_performance_dashboard_view.dart';

Map<String, dynamic> _sampleTelemetryPayload() {
  return <String, dynamic>{
    'overallStatus': 'UP',
    'timestampEpochMs': 1700000000000,
    'uptimeSeconds': 3725,
    'httpMetrics': <String, dynamic>{
      'totalRequests': 240,
      'success2xx': 228,
      'client4xx': 10,
      'server5xx': 2,
      'activeInFlight': 3,
      'avgLatencyMs': 18.4,
      'p95LatencyMs': 42.0,
      'maxLatencyMs': 95,
      'errorRatePercent': 5.0,
      'serverErrorRatePercent': 0.83,
    },
    'jvmMetrics': <String, dynamic>{
      'heapUsedMb': 192,
      'heapCommittedMb': 256,
      'heapMaxMb': 512,
      'heapUsedPercent': 37.5,
      'nonHeapUsedMb': 68,
      'threadCount': 34,
      'peakThreadCount': 40,
      'daemonThreadCount': 28,
      'gcCount': 12,
      'gcTimeMs': 84,
      'processCpuPercent': 14.2,
      'systemLoadAverage': 0.75,
      'availableProcessors': 8,
    },
    'databasePool': <String, dynamic>{
      'pingMs': 2.1,
      'status': 'UP',
      'poolName': 'HikariPool-1',
      'maximumPoolSize': 10,
      'minimumIdle': 2,
      'activeConnections': 2,
      'idleConnections': 8,
      'totalConnections': 10,
      'threadsAwaitingConnection': 0,
      'utilizationPercent': 20.0,
    },
    'realtimeMetrics': <String, dynamic>{'sseConnectedUsers': 7},
    'telemetryHistory': <Map<String, dynamic>>[
      <String, dynamic>{
        'timestampMs': 1699999980000,
        'label': '10:00:00',
        'heapUsedPercent': 34.0,
        'heapUsedMb': 174,
        'processCpuPercent': 10.5,
        'avgLatencyMs': 16.0,
        'p95LatencyMs': 35.0,
        'dbPingMs': 1.9,
        'threadCount': 32,
        'requestsDelta': 12,
        'totalRequests': 210,
        'hikariActive': 1,
      },
      <String, dynamic>{
        'timestampMs': 1699999990000,
        'label': '10:00:10',
        'heapUsedPercent': 36.2,
        'heapUsedMb': 185,
        'processCpuPercent': 12.8,
        'avgLatencyMs': 17.5,
        'p95LatencyMs': 39.0,
        'dbPingMs': 2.0,
        'threadCount': 33,
        'requestsDelta': 15,
        'totalRequests': 225,
        'hikariActive': 2,
      },
      <String, dynamic>{
        'timestampMs': 1700000000000,
        'label': '10:00:20',
        'heapUsedPercent': 37.5,
        'heapUsedMb': 192,
        'processCpuPercent': 14.2,
        'avgLatencyMs': 18.4,
        'p95LatencyMs': 42.0,
        'dbPingMs': 2.1,
        'threadCount': 34,
        'requestsDelta': 15,
        'totalRequests': 240,
        'hikariActive': 2,
      },
    ],
    'languageBreakdown': kSupportedLanguages
        .asMap()
        .entries
        .map(
          (entry) => <String, dynamic>{
            'language': entry.value,
            'students': 10 + entry.key * 3,
            'teachers': 2 + entry.key,
            'classes': 3 + entry.key,
            'exercises': 8 + entry.key * 2,
          },
        )
        .toList(),
    'profileDistribution': <String, dynamic>{
      'STUDENT': 42,
      'TEACHER': 8,
      'ADMIN': 2,
      'USER': 3,
    },
    'auditSeverityDistribution': <String, dynamic>{
      'INFO': 85,
      'WARN': 6,
      'ERROR': 1,
    },
  };
}

void main() {
  group('AdminPerformanceDashboardView FLChart & telemetry tests', () {
    testWidgets(
      'renders FLChart LineChart, BarChart, PieChart and switches sub-tabs without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var healthOpened = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminPerformanceDashboardView(
                onOpenSystemHealth: () => healthOpened = true,
                performanceLoader: () async => _sampleTelemetryPayload(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Centro de Performance & FLChart'), findsOneWidget);
        expect(find.byType(LineChart), findsWidgets);
        expect(find.byType(PieChart), findsWidgets);
        expect(find.byType(BarChart), findsWidgets);

        await tester.tap(find.text('JVM, CPU & HTTP'));
        await tester.pumpAndSettle();
        expect(find.byType(LineChart), findsWidgets);

        await tester.tap(find.text('6 Idiomas & Auditoria'));
        await tester.pumpAndSettle();
        expect(find.byType(BarChart), findsWidgets);
        expect(find.byType(PieChart), findsWidgets);

        await tester.tap(find.text('Saúde Detalhada'));
        expect(healthOpened, isTrue);
      },
    );

    testWidgets(
      'shows loading skeleton first and error retry state on failure',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final completer = Completer<Map<String, dynamic>>();
        var failFirst = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminPerformanceDashboardView(
                performanceLoader: () {
                  if (failFirst) {
                    return completer.future;
                  }
                  return Future.value(_sampleTelemetryPayload());
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Centro de Performance & FLChart'), findsOneWidget);

        completer.completeError(Exception('falha simulada de telemetria'));
        await tester.pumpAndSettle();
        expect(find.text('Tentar novamente'), findsOneWidget);

        failFirst = false;
        await tester.tap(find.text('Tentar novamente'));
        await tester.pumpAndSettle();
        expect(find.byType(LineChart), findsWidgets);
      },
    );

    testWidgets('adapts cleanly on mobile width (390px) across all sub-tabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPerformanceDashboardView(
              performanceLoader: () async => _sampleTelemetryPayload(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsWidgets);

      await tester.ensureVisible(find.text('JVM, CPU & HTTP'));
      await tester.tap(find.text('JVM, CPU & HTTP'));
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsWidgets);

      await tester.ensureVisible(find.text('6 Idiomas & Auditoria'));
      await tester.tap(find.text('6 Idiomas & Auditoria'));
      await tester.pumpAndSettle();
      expect(find.byType(BarChart), findsWidgets);
    });
  });
}
