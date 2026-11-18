import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/constants/app_feedback_widgets.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/realtime_sync_service.dart';
import 'package:frontend/core/theme/admin_geral_theme.dart';
import 'package:frontend/core/ui/language_flag.dart';
import 'package:frontend/core/ui/motion_kit.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:frontend/features/dashboard/domain/entities/teacher_class_assignment.dart';
import '../app_user_avatar.dart';
import '../class_performance_line_chart_card.dart';
import 'teacher_student_notes_dialog.dart';

class _ClassAnalyticsBundle {
  const _ClassAnalyticsBundle({
    required this.analytics,
    required this.dashboard,
    this.errorMessage,
  });

  final Map<String, dynamic>? analytics;
  final Map<String, dynamic>? dashboard;
  final String? errorMessage;
}

class TeacherClassAnalyticsView extends StatefulWidget {
  const TeacherClassAnalyticsView({
    super.key,
    required this.data,
    required this.onBack,
    this.dio,
  });

  final DashboardData data;
  final VoidCallback onBack;
  final Dio? dio;

  @override
  State<TeacherClassAnalyticsView> createState() =>
      _TeacherClassAnalyticsViewState();
}

class _TeacherClassAnalyticsViewState extends State<TeacherClassAnalyticsView> {
  late final Dio _dio = widget.dio ?? ApiClient().dio;
  late Future<void> _loadFuture;
  StreamSubscription<RealtimeSyncEvent>? _realtimeSub;

  /// When null and the teacher has multiple classes, shows all classes in separated
  /// per-class sections; when non-null, focuses on a single class.
  int? _selectedClassId;
  final Map<int, _ClassAnalyticsBundle> _bundles = {};

  List<TeacherClassAssignment> get _activeAssignments => widget
      .data
      .teacherAssignments
      .where((a) => a.isActive && a.schoolClassId != null)
      .toList();

  @override
  void initState() {
    super.initState();
    final assignments = _activeAssignments;
    if (assignments.length == 1) {
      _selectedClassId = assignments.first.schoolClassId;
    } else {
      _selectedClassId = null;
    }
    _loadFuture = _fetchAllVisible();
    _realtimeSub = RealtimeSyncService.instance.events.listen((event) {
      if (!mounted) return;
      if (event.type == 'EXERCISE_SUBMITTED' ||
          event.type == 'RANKING_UPDATED' ||
          event.type == 'ENROLLMENT_UPDATED') {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadFuture = _fetchAllVisible();
    });
    await _loadFuture;
  }

  Future<_ClassAnalyticsBundle> _fetchBundleForClass(int classId) async {
    Map<String, dynamic>? analytics;
    Map<String, dynamic>? dashboard;
    String? errorMsg;

    await Future.wait([
      _dio
          .get('/api/classes/$classId/analytics')
          .then((res) {
            if (res.data is Map) {
              analytics = Map<String, dynamic>.from(res.data as Map);
            }
          })
          .catchError((e) {
            errorMsg = 'Erro ao carregar analytics da turma: $e';
          }),
      _dio
          .get('/api/classes/$classId/dashboard')
          .then((res) {
            if (res.data is Map) {
              dashboard = Map<String, dynamic>.from(res.data as Map);
            }
          })
          .catchError((_) {
            // Optional enrichment endpoint; analytics renders standalone fallback
          }),
    ]);

    return _ClassAnalyticsBundle(
      analytics: analytics,
      dashboard: dashboard,
      errorMessage: analytics == null ? errorMsg : null,
    );
  }

  Future<void> _fetchAllVisible() async {
    final assignments = _activeAssignments;
    if (assignments.isEmpty) return;

    final targetIds = _selectedClassId != null
        ? <int>[_selectedClassId!]
        : assignments.map((a) => a.schoolClassId!).toList();

    final entries = await Future.wait(
      targetIds.map((id) async => MapEntry(id, await _fetchBundleForClass(id))),
    );
    if (!mounted) return;
    setState(() {
      for (final entry in entries) {
        _bundles[entry.key] = entry.value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final assignments = _activeAssignments;
    final visibleAssignments = _selectedClassId == null
        ? assignments
        : assignments
              .where((a) => a.schoolClassId == _selectedClassId)
              .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Analytics Pedagógico da Turma'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar gráficos das turmas',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: assignments.isEmpty
          ? const Center(
              child: Text('Nenhuma turma associada a este professor.'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Class Filter Strip (Todas separadas vs Turma individual)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.analytics_rounded,
                              color: Color(0xFF7651C8),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                assignments.length > 1
                                    ? 'Análise Separada por Turma (${assignments.length} turmas ativas)'
                                    : 'Análise Detalhada da Turma',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (assignments.length > 1)
                              ChoiceChip(
                                avatar: const Icon(
                                  Icons.grid_view_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  'Todas separadas (${assignments.length})',
                                ),
                                selected: _selectedClassId == null,
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (!selected || _selectedClassId == null) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedClassId = null;
                                    _loadFuture = _fetchAllVisible();
                                  });
                                },
                              ),
                            for (final a in assignments)
                              ChoiceChip(
                                avatar: LanguageFlag.forLanguage(
                                  a.resolvedLanguage,
                                  width: 18,
                                ),
                                label: Text(a.schoolClassName),
                                selected: _selectedClassId == a.schoolClassId,
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (!selected ||
                                      _selectedClassId == a.schoolClassId) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedClassId = a.schoolClassId;
                                    _loadFuture = _fetchAllVisible();
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                FutureBuilder<void>(
                  future: _loadFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _bundles.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: AppLoader(
                          message: 'Calculando analytics das turmas...',
                          accentColor: Color(0xFF7651C8),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < visibleAssignments.length; i++) ...[
                          _buildClassAnalyticsSection(
                            context,
                            assignment: visibleAssignments[i],
                            bundle:
                                _bundles[visibleAssignments[i].schoolClassId!],
                            isFocusedView:
                                _selectedClassId != null ||
                                assignments.length == 1,
                          ),
                          if (i < visibleAssignments.length - 1)
                            const SizedBox(height: 22),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildClassAnalyticsSection(
    BuildContext context, {
    required TeacherClassAssignment assignment,
    required _ClassAnalyticsBundle? bundle,
    required bool isFocusedView,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final classId = assignment.schoolClassId!;

    if (bundle == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: AppLoader(
            message: 'Carregando gráficos da turma...',
            accentColor: Color(0xFF7651C8),
          ),
        ),
      );
    }

    final analytics = bundle.analytics;
    if (analytics == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              LanguageFlag.forLanguage(assignment.resolvedLanguage, width: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.schoolClassName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bundle.errorMessage ??
                          'Dados não disponíveis para esta turma.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final totalStudents = (analytics['totalStudents'] as num?)?.toInt() ?? 0;
    final activeStudents =
        (analytics['activeStudentsPastWeek'] as num?)?.toInt() ?? 0;
    final accuracy =
        (analytics['averageAccuracyPercent'] as num?)?.toDouble() ?? 0.0;
    final totalSubmissions =
        (analytics['totalSubmissions'] as num?)?.toInt() ?? 0;
    final pendingGrading = (analytics['pendingGrading'] as num?)?.toInt() ?? 0;
    final rawCefr =
        (analytics['cefrDistribution'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
        ) ??
        const <String, int>{};
    final atRisk = List<Map<String, dynamic>>.from(
      analytics['studentsNeedingAttention'] ?? const [],
    );

    final dash = bundle.dashboard;
    final totalXp = (dash?['totalXpEarned'] as num?)?.toInt() ?? 0;
    final exercisesCount =
        (dash?['exercises'] as List?)?.length ??
        (totalSubmissions > 0 ? 1 : 0);
    final studentsPerf = ((dash?['students'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final effectiveDashboard = <String, dynamic>{
      ...?dash,
      'totalStudents': totalStudents,
      'totalSubmissions': totalSubmissions,
      'totalXpEarned': totalXp,
      'averageAccuracyPercent': accuracy,
    };

    final activeRatio = totalStudents > 0
        ? (activeStudents / totalStudents).clamp(0.0, 1.0)
        : 0.0;
    final gradedCount = math.max(0, totalSubmissions - pendingGrading);
    final gradedRatio = totalSubmissions > 0
        ? (gradedCount / totalSubmissions).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Class Header Banner
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7651C8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: LanguageFlag.forLanguage(
                      assignment.resolvedLanguage,
                      width: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.schoolClassName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${assignment.resolvedLanguage} • $totalStudents aluno(s) • $exercisesCount atividade(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!isFocusedView)
                FilledButton.tonalIcon(
                  onPressed: () {
                    setState(() {
                      _selectedClassId = classId;
                      _loadFuture = _fetchAllVisible();
                    });
                  },
                  icon: const Icon(Icons.zoom_in_rounded, size: 18),
                  label: const Text('Analisar detalhes'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Admin-style Radial Telemetry Gauge Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 1020
                  ? 4
                  : constraints.maxWidth >= 580
                  ? 2
                  : 1;
              const spacing = 12.0;
              final cardW =
                  (constraints.maxWidth - (spacing * (cols - 1))) / cols;
              final gauges = [
                _ClassTelemetryGaugeCard(
                  title: 'Engajamento (7d)',
                  metricValue: activeStudents,
                  metricSuffix: ' / $totalStudents',
                  subtitle: '$totalStudents aluno(s) na turma',
                  percent: activeRatio,
                  centerText: '${(activeRatio * 100).round()}%',
                  centerSub: 'Ativos',
                  color: const Color(0xFF2563EB),
                  icon: Icons.people_alt_rounded,
                ),
                _ClassTelemetryGaugeCard(
                  title: 'Precisão Média',
                  metricValue: accuracy,
                  metricDecimals: 1,
                  metricSuffix: '%',
                  subtitle: 'Média de acertos da turma',
                  percent: (accuracy / 100.0).clamp(0.0, 1.0),
                  centerText: '${accuracy.toStringAsFixed(0)}%',
                  centerSub: 'Acurácia',
                  color: accuracy >= 70
                      ? const Color(0xFF059669)
                      : const Color(0xFFD97706),
                  icon: Icons.gps_fixed_rounded,
                ),
                _ClassTelemetryGaugeCard(
                  title: 'Entregas & Correções',
                  metricValue: totalSubmissions,
                  metricSuffix: ' envios',
                  subtitle: pendingGrading > 0
                      ? '$pendingGrading aguardando correção'
                      : 'Todas as entregas avaliadas',
                  percent: gradedRatio,
                  centerText: '${(gradedRatio * 100).round()}%',
                  centerSub: 'Avaliadas',
                  color: const Color(0xFF7C3AED),
                  icon: Icons.assignment_turned_in_rounded,
                ),
                _ClassTelemetryGaugeCard(
                  title: 'XP & Alunos em Risco',
                  metricValue: totalXp > 0 ? totalXp : atRisk.length,
                  metricSuffix: totalXp > 0 ? ' XP' : ' alertas',
                  subtitle:
                      '${atRisk.length} aluno(s) precisa(m) de atenção',
                  percent: totalStudents > 0
                      ? ((totalStudents - atRisk.length) / totalStudents).clamp(
                          0.0,
                          1.0,
                        )
                      : 1.0,
                  centerText: '${atRisk.length}',
                  centerSub: 'Alertas',
                  color: atRisk.isEmpty
                      ? AdminGeralTheme.goldMetallic
                      : const Color(0xFFDC2626),
                  icon: atRisk.isEmpty
                      ? Icons.bolt_rounded
                      : Icons.warning_amber_rounded,
                ),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(
                  gauges.length,
                  (i) => SizedBox(
                    width: cardW,
                    child: StaggeredReveal(index: i + 1, child: gauges[i]),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // CPU/Investment Multi-Line Chart + CEFR & Accuracy Donut Pie
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final lineChart = ClassPerformanceLineChartCard(
                dashboard: effectiveDashboard,
                title: 'Curva de Desempenho — ${assignment.schoolClassName}',
              );
              final pieChart = _buildCefrAndHealthPieCard(
                context,
                className: assignment.schoolClassName,
                cefrDistribution: rawCefr,
                accuracy: accuracy,
                pendingGrading: pendingGrading,
                totalSubmissions: totalSubmissions,
              );
              if (!isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    lineChart,
                    const SizedBox(height: 14),
                    pieChart,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: lineChart),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: pieChart),
                ],
              );
            },
          ),

          if (isFocusedView) ...[
            if (studentsPerf.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Estudantes da Turma (${studentsPerf.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              for (var idx = 0; idx < studentsPerf.length; idx++)
                _buildStudentSummaryRow(context, studentsPerf[idx], idx + 1),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Alunos que Precisam de Atenção (${atRisk.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (atRisk.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Excelente! Nenhum aluno com pendência crítica ou baixo rendimento detectado nesta turma.',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...atRisk.map((student) {
                final name = student['studentName'] as String? ?? 'Estudante';
                final sId = (student['studentId'] as num?)?.toInt() ?? 0;
                final reason = student['riskReason'] as String? ?? '';
                final avg =
                    (student['averageAccuracy'] as num?)?.toDouble() ?? 0.0;
                final daysInactive =
                    (student['daysInactive'] as num?)?.toInt() ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reason,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Precisão: ${avg.toStringAsFixed(1)}% | Inativo há $daysInactive dia(s)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: OutlinedButton.icon(
                      icon: const Icon(Icons.note_add_rounded, size: 16),
                      label: const Text('Anotações'),
                      onPressed: () {
                        TeacherStudentNotesDialog.show(
                          context,
                          studentId: sId,
                          studentName: name,
                          classId: classId,
                        );
                      },
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentSummaryRow(
    BuildContext context,
    Map<String, dynamic> student,
    int rank,
  ) {
    final colors = Theme.of(context).colorScheme;
    final name = student['name']?.toString() ?? 'Estudante';
    final pic = student['profilePicture']?.toString();
    final acc = (student['averageAccuracyPercent'] as num?)?.toDouble() ?? 0.0;
    final subs = (student['submissionsCount'] as num?)?.toInt() ?? 0;
    final xp = (student['xpEarned'] as num?)?.toInt() ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: ListTile(
        leading: AppUserAvatar(name: name, pictureUrl: pic, radius: 18),
        title: Text(
          '#$rank · $name',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '$subs entrega(s) • Precisão ${acc.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        trailing: Text(
          '$xp XP',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF7C3AED),
          ),
        ),
      ),
    );
  }

  Widget _buildCefrAndHealthPieCard(
    BuildContext context, {
    required String className,
    required Map<String, int> cefrDistribution,
    required double accuracy,
    required int pendingGrading,
    required int totalSubmissions,
  }) {
    const palette = <Color>[
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFF7C3AED),
      AdminGeralTheme.goldMetallic,
      Color(0xFFDB2777),
      Color(0xFF0891B2),
    ];

    final nonZeroCefr = cefrDistribution.entries
        .where((e) => e.value > 0)
        .toList();
    final List<({String label, double value, Color color})> slices;
    final String cardTitle;
    if (nonZeroCefr.isNotEmpty) {
      cardTitle = 'Níveis CEFR — $className';
      slices = [
        for (var i = 0; i < nonZeroCefr.length; i++)
          (
            label: nonZeroCefr[i].key,
            value: nonZeroCefr[i].value.toDouble(),
            color: palette[i % palette.length],
          ),
      ];
    } else {
      cardTitle = 'Acertos vs Pendências';
      final correctShare = accuracy.clamp(0.0, 100.0);
      final gapShare = (100.0 - correctShare).clamp(0.0, 100.0);
      slices = [
        if (correctShare > 0)
          (
            label: 'Acurácia',
            value: correctShare,
            color: const Color(0xFF059669),
          ),
        if (gapShare > 0)
          (
            label: 'Margem de erro',
            value: gapShare,
            color: const Color(0xFFDC2626),
          ),
        if (pendingGrading > 0)
          (
            label: 'Pendentes',
            value: (pendingGrading * 10.0),
            color: AdminGeralTheme.goldMetallic,
          ),
      ];
    }

    final total = slices.fold<double>(0, (sum, s) => sum + s.value);

    return InteractiveMotionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: total <= 0 || (totalSubmissions == 0 && nonZeroCefr.isEmpty)
                ? const Center(child: Text('Sem amostras suficientes'))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: slices.map((s) {
                        final pct = ((s.value / total) * 100).toStringAsFixed(
                          0,
                        );
                        return PieChartSectionData(
                          color: s.color,
                          value: s.value,
                          title: '$pct%',
                          radius: 42,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final s in slices)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      nonZeroCefr.isNotEmpty
                          ? '${s.label}: ${s.value.toInt()}'
                          : s.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassTelemetryGaugeCard extends StatelessWidget {
  const _ClassTelemetryGaugeCard({
    required this.title,
    required this.metricValue,
    required this.metricSuffix,
    required this.subtitle,
    required this.percent,
    required this.centerText,
    required this.centerSub,
    required this.color,
    required this.icon,
    this.metricDecimals = 0,
  });

  final String title;
  final num metricValue;
  final int metricDecimals;
  final String metricSuffix;
  final String subtitle;
  final double percent;
  final String centerText;
  final String centerSub;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InteractiveMotionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AnimatedRadialGauge(
            percent: percent,
            color: color,
            centerLabel: centerText,
            subtitle: centerSub,
            radius: 32,
            lineWidth: 6.5,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 15, color: color),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedMetricCounter(
                  value: metricValue,
                  decimals: metricDecimals,
                  suffix: metricSuffix,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
