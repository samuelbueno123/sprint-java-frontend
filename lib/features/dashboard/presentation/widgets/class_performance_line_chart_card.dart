import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/admin_geral_theme.dart';
import '../../../../core/ui/motion_kit.dart';

class _PerformanceMetricSeries {
  const _PerformanceMetricSeries({
    required this.key,
    required this.label,
    required this.color,
    required this.spots,
    required this.currentValue,
    required this.deltaValue,
  });

  final String key;
  final String label;
  final Color color;
  final List<FlSpot> spots;
  final double currentValue;
  final double deltaValue;
}

class _NormalizedClassPoint {
  const _NormalizedClassPoint({
    required this.label,
    required this.accuracyPercent,
    required this.participationPercent,
    required this.xpProgressPercent,
    required this.overallScorePercent,
    required this.submissionsCount,
    required this.cumulativeXp,
  });

  final String label;
  final double accuracyPercent;
  final double participationPercent;
  final double xpProgressPercent;
  final double overallScorePercent;
  final int submissionsCount;
  final int cumulativeXp;
}

/// Investment / CPU-style multi-line performance chart displayed inside a class
/// so students, teachers, and administrators can all track accuracy,
/// participation, XP growth, and overall class index together.
class ClassPerformanceLineChartCard extends StatefulWidget {
  const ClassPerformanceLineChartCard({
    super.key,
    required this.dashboard,
    this.title = 'Curva de Desempenho da Turma',
  });

  final Map<String, dynamic> dashboard;
  final String title;

  @override
  State<ClassPerformanceLineChartCard> createState() =>
      _ClassPerformanceLineChartCardState();
}

class _ClassPerformanceLineChartCardState
    extends State<ClassPerformanceLineChartCard> {
  final Set<String> _enabledSeries = {
    'accuracy',
    'participation',
    'xpProgress',
    'overall',
  };

  void _toggleSeries(String key) {
    setState(() {
      if (_enabledSeries.contains(key)) {
        if (_enabledSeries.length > 1) {
          _enabledSeries.remove(key);
        }
      } else {
        _enabledSeries.add(key);
      }
    });
  }

  List<_NormalizedClassPoint> _resolvePoints() {
    final rawSeries = widget.dashboard['performanceSeries'] as List<dynamic>?;
    if (rawSeries != null && rawSeries.isNotEmpty) {
      final parsed = rawSeries.whereType<Map>().map((item) {
        return _NormalizedClassPoint(
          label: item['label']?.toString() ?? '',
          accuracyPercent:
              ((item['accuracyPercent'] as num?) ?? 0).toDouble().clamp(
                0.0,
                100.0,
              ),
          participationPercent:
              ((item['participationPercent'] as num?) ?? 0).toDouble().clamp(
                0.0,
                100.0,
              ),
          xpProgressPercent:
              ((item['xpProgressPercent'] as num?) ?? 0).toDouble().clamp(
                0.0,
                100.0,
              ),
          overallScorePercent:
              ((item['overallScorePercent'] as num?) ?? 0).toDouble().clamp(
                0.0,
                100.0,
              ),
          submissionsCount: (item['submissionsCount'] as num?)?.toInt() ?? 0,
          cumulativeXp: (item['cumulativeXp'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      if (parsed.isNotEmpty) return parsed;
    }

    // Fallback synthesis when rendering summary payloads without explicit series
    final exercises = (widget.dashboard['exercises'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .toList();
    final totalStudents = math.max(
      1,
      (widget.dashboard['totalStudents'] as num?)?.toInt() ?? 1,
    );
    final avgAcc =
        ((widget.dashboard['averageAccuracyPercent'] as num?) ?? 0).toDouble();
    final totalSubs =
        (widget.dashboard['totalSubmissions'] as num?)?.toInt() ?? 0;
    final totalXp = (widget.dashboard['totalXpEarned'] as num?)?.toInt() ?? 0;

    if (exercises.isEmpty && totalSubs == 0) {
      return const [];
    }

    if (exercises.isEmpty) {
      final part = ((totalSubs * 100.0) / totalStudents).clamp(0.0, 100.0);
      final xpPct = ((totalXp * 100.0) / math.max(20, totalXp)).clamp(
        0.0,
        100.0,
      );
      final overall = (avgAcc * 0.45 + part * 0.30 + xpPct * 0.25).clamp(
        0.0,
        100.0,
      );
      return [
        const _NormalizedClassPoint(
          label: 'Início',
          accuracyPercent: 0,
          participationPercent: 0,
          xpProgressPercent: 0,
          overallScorePercent: 0,
          submissionsCount: 0,
          cumulativeXp: 0,
        ),
        _NormalizedClassPoint(
          label: 'Atual',
          accuracyPercent: avgAcc.clamp(0.0, 100.0),
          participationPercent: part,
          xpProgressPercent: xpPct,
          overallScorePercent: overall,
          submissionsCount: totalSubs,
          cumulativeXp: totalXp,
        ),
      ];
    }

    final points = <_NormalizedClassPoint>[];
    if (exercises.length == 1) {
      points.add(
        const _NormalizedClassPoint(
          label: 'Início',
          accuracyPercent: 0,
          participationPercent: 0,
          xpProgressPercent: 0,
          overallScorePercent: 0,
          submissionsCount: 0,
          cumulativeXp: 0,
        ),
      );
    }

    var cumSubs = 0;
    for (var i = 0; i < exercises.length; i++) {
      final ex = exercises[i];
      final exAcc = ((ex['averageAccuracyPercent'] as num?) ?? avgAcc)
          .toDouble()
          .clamp(0.0, 100.0);
      final exSubs = (ex['submissionsCount'] as num?)?.toInt() ?? 0;
      cumSubs += exSubs;
      final part = ((exSubs * 100.0) / totalStudents).clamp(0.0, 100.0);
      final xpShare = exercises.isNotEmpty
          ? ((cumSubs * 100.0) / math.max(1, totalSubs)).clamp(0.0, 100.0)
          : 0.0;
      final overall = (exAcc * 0.45 + part * 0.30 + xpShare * 0.25).clamp(
        0.0,
        100.0,
      );
      final rawTitle = ex['title']?.toString().trim() ?? 'Atv ${i + 1}';
      final shortTitle = rawTitle.length > 10
          ? '${rawTitle.substring(0, 9)}…'
          : rawTitle;
      points.add(
        _NormalizedClassPoint(
          label: shortTitle,
          accuracyPercent: exAcc,
          participationPercent: part,
          xpProgressPercent: xpShare,
          overallScorePercent: overall,
          submissionsCount: cumSubs,
          cumulativeXp: totalSubs > 0 ? ((totalXp * cumSubs) ~/ totalSubs) : 0,
        ),
      );
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final points = _resolvePoints();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    final seriesList = [
      _PerformanceMetricSeries(
        key: 'overall',
        label: 'Índice Geral',
        color: const Color(0xFF7C3AED),
        spots: [
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].overallScorePercent),
        ],
        currentValue: points.isEmpty ? 0 : points.last.overallScorePercent,
        deltaValue: points.length < 2
            ? 0
            : (points.last.overallScorePercent -
                  points.first.overallScorePercent),
      ),
      _PerformanceMetricSeries(
        key: 'accuracy',
        label: 'Acurácia %',
        color: const Color(0xFF10B981),
        spots: [
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].accuracyPercent),
        ],
        currentValue: points.isEmpty ? 0 : points.last.accuracyPercent,
        deltaValue: points.length < 2
            ? 0
            : (points.last.accuracyPercent - points.first.accuracyPercent),
      ),
      _PerformanceMetricSeries(
        key: 'participation',
        label: 'Participação %',
        color: const Color(0xFF2563EB),
        spots: [
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].participationPercent),
        ],
        currentValue: points.isEmpty ? 0 : points.last.participationPercent,
        deltaValue: points.length < 2
            ? 0
            : (points.last.participationPercent -
                  points.first.participationPercent),
      ),
      _PerformanceMetricSeries(
        key: 'xpProgress',
        label: 'Evolução XP %',
        color: AdminGeralTheme.goldMetallic,
        spots: [
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].xpProgressPercent),
        ],
        currentValue: points.isEmpty ? 0 : points.last.xpProgressPercent,
        deltaValue: points.length < 2
            ? 0
            : (points.last.xpProgressPercent - points.first.xpProgressPercent),
      ),
    ];

    final activeSeries = seriesList
        .where((s) => _enabledSeries.contains(s.key))
        .toList();
    final overallSeries = seriesList.first;
    final positiveDelta = overallSeries.deltaValue >= 0;

    return InteractiveMotionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.candlestick_chart_rounded,
                      color: Color(0xFF7C3AED),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Acurácia, Participação, Evolução XP e Índice Geral na mesma escala',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (points.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (positiveDelta
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444))
                            .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        positiveDelta
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 15,
                        color: positiveDelta
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${overallSeries.currentValue.toStringAsFixed(1)}% '
                        '(${positiveDelta ? '+' : ''}${overallSeries.deltaValue.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: positiveDelta
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: seriesList.map((s) {
              final selected = _enabledSeries.contains(s.key);
              return FilterChip(
                selected: selected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => _toggleSeries(s.key),
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: selected ? s.color : colors.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(
                  points.isEmpty
                      ? s.label
                      : '${s.label}: ${s.currentValue.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? colors.onSurface : colors.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 235,
            child: points.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          size: 36,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Realize atividades na turma para acompanhar o gráfico de evolução.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.4),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                        drawVerticalLine: false,
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            interval: 25,
                            getTitlesWidget: (v, _) => Text(
                              '${v.toInt()}%',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: (points.length / 4)
                                .clamp(1, 10)
                                .toDouble(),
                            getTitlesWidget: (val, _) {
                              final idx = val.round();
                              if (idx < 0 || idx >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  points[idx].label,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF1E293B),
                          getTooltipItems: (spots) => spots.map((s) {
                            final idx = s.x.round();
                            final pt = (idx >= 0 && idx < points.length)
                                ? points[idx]
                                : null;
                            final metric = activeSeries[s.barIndex];
                            final extra =
                                metric.key == 'xpProgress' && pt != null
                                ? ' (${pt.cumulativeXp} XP)'
                                : '';
                            final prefix =
                                pt != null &&
                                    pt.label.isNotEmpty &&
                                    s.barIndex == 0
                                ? '${pt.label}\n'
                                : '';
                            return LineTooltipItem(
                              '$prefix${metric.label}: ${s.y.toStringAsFixed(1)}%$extra',
                              TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      lineBarsData: activeSeries.map((s) {
                        return LineChartBarData(
                          spots: s.spots,
                          isCurved: s.spots.length > 2,
                          color: s.color,
                          barWidth: s.key == 'overall' ? 3.2 : 2.5,
                          dotData: FlDotData(show: s.spots.length <= 10),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                s.color.withValues(alpha: 0.22),
                                s.color.withValues(alpha: 0.01),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    duration: const Duration(milliseconds: 350),
                  ),
          ),
        ],
      ),
    );
  }
}
