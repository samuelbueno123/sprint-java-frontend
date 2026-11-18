import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/constants/app_feedback_widgets.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/theme/admin_geral_theme.dart';
import '../../../../../core/ui/motion_kit.dart';
import '../responsive_layout.dart';

class AdminSystemHealthView extends StatefulWidget {
  const AdminSystemHealthView({
    super.key,
    this.dio,
    this.healthLoader,
  });

  final Dio? dio;
  final Future<Map<String, dynamic>> Function()? healthLoader;

  @override
  State<AdminSystemHealthView> createState() => _AdminSystemHealthViewState();
}

class _AdminSystemHealthViewState extends State<AdminSystemHealthView> {
  late final Dio _dio = widget.dio ?? ApiClient().dio;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _healthData;
  final List<_HealthSamplePoint> _healthHistory = [];
  Timer? _autoRefreshTimer;
  bool _autoRefresh = false;

  @override
  void initState() {
    super.initState();
    _loadHealth();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoRefresh(bool value) {
    setState(() {
      _autoRefresh = value;
      _autoRefreshTimer?.cancel();
      if (_autoRefresh) {
        _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          _loadHealth(isBackground: true);
        });
      }
    });
  }

  Future<void> _loadHealth({bool isBackground = false}) async {
    if (!isBackground && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final Map<String, dynamic> payload;
      if (widget.healthLoader != null) {
        payload = await widget.healthLoader!.call();
      } else {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/admin/system/health',
        );
        payload = Map<String, dynamic>.from(response.data ?? const {});
      }

      if (!mounted) return;
      final db = payload['database'] as Map<String, dynamic>?;
      final sys = payload['systemResources'] as Map<String, dynamic>?;
      final active = (db?['activeConnections'] as num?)?.toDouble() ?? 0.0;
      final maxPool = (db?['maximumPoolSize'] as num?)?.toDouble() ?? 25.0;
      final poolPct = maxPool > 0
          ? ((active / maxPool) * 100.0).clamp(0.0, 100.0)
          : 0.0;
      final heapPct = ((sys?['memoryUsedPercent'] as num?) ?? 0.0)
          .toDouble()
          .clamp(0.0, 100.0);
      final sysCpuPct =
          ((sys?['systemCpuPercent'] as num?) ??
                  (sys?['processCpuPercent'] as num?) ??
                  0.0)
              .toDouble()
              .clamp(0.0, 100.0);
      final pingMs = ((db?['pingMs'] as num?) ?? 0.0).toDouble();

      final now = DateTime.now();
      final label =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';

      setState(() {
        _healthData = payload;
        _errorMessage = null;
        if (_healthHistory.length >= 24) {
          _healthHistory.removeAt(0);
        }
        _healthHistory.add(
          _HealthSamplePoint(
            label: label,
            heapPct: heapPct,
            cpuPct: sysCpuPct,
            poolPct: poolPct,
            pingMs: pingMs,
          ),
        );
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (!isBackground) {
        setState(() {
          _errorMessage =
              e.response?.data?['message']?.toString() ??
              'Falha ao consultar saúde do sistema (${e.message}).';
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (!isBackground) {
        setState(() {
          _errorMessage = 'Erro ao verificar métricas: $e';
        });
      }
    } finally {
      if (mounted && !isBackground) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'UP':
        return const Color(0xFF10B981);
      case 'DEGRADED':
        return AdminGeralTheme.goldMetallic;
      case 'DOWN':
      default:
        return const Color(0xFFEF4444);
    }
  }

  String _formatUptime(dynamic uptimeSeconds) {
    if (uptimeSeconds == null) return '-';
    final sec = (uptimeSeconds as num).toInt();
    final hours = sec ~/ 3600;
    final minutes = (sec % 3600) ~/ 60;
    final seconds = sec % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final overallStatus = _healthData?['status']?.toString() ?? 'UNKNOWN';

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: responsiveBannerPadding(context),
            decoration: AdminGeralTheme.heroDecoration(
              context: context,
              borderRadius: 22,
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.monitor_heart_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Monitoramento & Diagnóstico',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    overallStatus,
                                  ).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white),
                                ),
                                child: Text(
                                  'STATUS: $overallStatus',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Inspeção em tempo real com gráficos FLChart de banco de dados, HikariCP, CPU/RAM e serviços.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Auto (10s):',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Switch(
                      value: _autoRefresh,
                      onChanged: _toggleAutoRefresh,
                      activeThumbColor: Colors.white,
                    ),
                    IconButton(
                      onPressed: () => _loadHealth(),
                      tooltip: 'Atualizar agora',
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 20),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF87171)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: AppLoader(
                message: 'Monitorando saúde e serviços do sistema...',
                accentColor: AdminGeralTheme.indigoMid,
              ),
            )
          else if (_healthData != null) ...[
            // Gráficos de Saúde (Linha Temporal + Rosca HikariCP + Barras de Subsistemas)
            _buildHealthChartsRow(
              isDesktop: isDesktop,
              db: _healthData!['database'] as Map<String, dynamic>?,
              jvm: _healthData!['systemResources'] as Map<String, dynamic>?,
              ai: _healthData!['externalAi'] as Map<String, dynamic>?,
            ),
            const SizedBox(height: 18),

            // Cards detalhados responsivos (2 colunas no desktop, 1 no mobile)
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  _buildDbCard(
                    _healthData!['database'] as Map<String, dynamic>?,
                  ),
                  _buildJvmCard(
                    _healthData!['systemResources'] as Map<String, dynamic>?,
                  ),
                  _buildAiCard(
                    _healthData!['externalAi'] as Map<String, dynamic>?,
                  ),
                  _buildAppCard(
                    _healthData!['application'] as Map<String, dynamic>?,
                  ),
                ];
                if (isDesktop) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[1]),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 14),
                    cards[1],
                    const SizedBox(height: 14),
                    cards[2],
                    const SizedBox(height: 14),
                    cards[3],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthChartsRow({
    required bool isDesktop,
    required Map<String, dynamic>? db,
    required Map<String, dynamic>? jvm,
    required Map<String, dynamic>? ai,
  }) {
    final trendChart = _buildHealthTrendLineCard();
    final subsystemsChart = _buildSubsystemUtilizationBarCard(
      db: db,
      jvm: jvm,
    );
    final poolDonutChart = _buildPoolDistributionPieCard(db: db, ai: ai);

    if (isDesktop) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: trendChart),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: poolDonutChart),
            ],
          ),
          const SizedBox(height: 16),
          subsystemsChart,
        ],
      );
    }

    return Column(
      children: [
        trendChart,
        const SizedBox(height: 14),
        poolDonutChart,
        const SizedBox(height: 14),
        subsystemsChart,
      ],
    );
  }

  Widget _buildHealthTrendLineCard() {
    final heapSpots = <FlSpot>[];
    final cpuSpots = <FlSpot>[];
    final poolSpots = <FlSpot>[];
    double maxObserved = 15.0;

    for (var i = 0; i < _healthHistory.length; i++) {
      final point = _healthHistory[i];
      if (point.heapPct > maxObserved) maxObserved = point.heapPct;
      if (point.cpuPct > maxObserved) maxObserved = point.cpuPct;
      if (point.poolPct > maxObserved) maxObserved = point.poolPct;
      heapSpots.add(FlSpot(i.toDouble(), point.heapPct));
      cpuSpots.add(FlSpot(i.toDouble(), point.cpuPct));
      poolSpots.add(FlSpot(i.toDouble(), point.poolPct));
    }

    final maxY = maxObserved <= 18
        ? 25.0
        : (maxObserved <= 40 ? 50.0 : (maxObserved <= 70 ? 80.0 : 100.0));
    final interval = maxY / 4;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timeline_rounded, color: Color(0xFF4F46E5)),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Curva de Saúde em Tempo Real (%)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _LegendItem(color: Color(0xFF8B5CF6), label: 'Heap %'),
                    _LegendItem(
                      color: AdminGeralTheme.goldMetallic,
                      label: 'CPU %',
                    ),
                    _LegendItem(color: Color(0xFF0284C7), label: 'Hikari %'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Leituras capturadas nesta sessão (${_healthHistory.length} amostra(s) · escala 0–${maxY.toInt()}%).',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 195,
              child: heapSpots.isEmpty
                  ? const Center(child: Text('Aguardando amostra...'))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: interval,
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
                              reservedSize: 36,
                              interval: interval,
                              getTitlesWidget: (v, _) => Text(
                                '${v.toInt()}%',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: (_healthHistory.length / 4)
                                  .clamp(1, 8)
                                  .toDouble(),
                              getTitlesWidget: (val, _) {
                                final idx = val.round();
                                if (idx < 0 || idx >= _healthHistory.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(
                                    _healthHistory[idx].label,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) => spots.map((s) {
                              final label = switch (s.barIndex) {
                                0 => 'Heap',
                                1 => 'CPU',
                                _ => 'Hikari Pool',
                              };
                              return LineTooltipItem(
                                '$label: ${s.y.toStringAsFixed(1)}%',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: heapSpots,
                            isCurved: heapSpots.length > 2,
                            color: const Color(0xFF8B5CF6),
                            barWidth: 3,
                            dotData: FlDotData(show: heapSpots.length <= 12),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(
                                0xFF8B5CF6,
                              ).withValues(alpha: 0.14),
                            ),
                          ),
                          LineChartBarData(
                            spots: cpuSpots,
                            isCurved: cpuSpots.length > 2,
                            color: AdminGeralTheme.goldMetallic,
                            barWidth: 2.8,
                            dotData: FlDotData(show: cpuSpots.length <= 12),
                          ),
                          LineChartBarData(
                            spots: poolSpots,
                            isCurved: poolSpots.length > 2,
                            color: const Color(0xFF0284C7),
                            barWidth: 2.6,
                            dotData: FlDotData(show: poolSpots.length <= 12),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoolDistributionPieCard({
    required Map<String, dynamic>? db,
    required Map<String, dynamic>? ai,
  }) {
    final active = (db?['activeConnections'] as num?)?.toDouble() ?? 0.0;
    final idle = (db?['idleConnections'] as num?)?.toDouble() ?? 0.0;
    final maxPool = (db?['maximumPoolSize'] as num?)?.toDouble() ?? 25.0;
    final freeSlots = (maxPool - active - idle).clamp(0.0, maxPool);
    final total = active + idle + freeSlots;
    final aiStatus = ai?['status']?.toString() ?? 'NOT_CONFIGURED';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.donut_large_rounded, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Text(
                      'Capacidade do Pool Hikari',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                _statusBadge(aiStatus == 'UP' ? 'IA ON' : aiStatus),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: total <= 0
                  ? const Center(child: Text('Sem dados de pool.'))
                  : PieChart(
                      PieChartData(
                        centerSpaceRadius: 34,
                        sectionsSpace: 3,
                        sections: [
                          PieChartSectionData(
                            value: active <= 0 ? 0.001 : active,
                            color: const Color(0xFF10B981),
                            radius: 42,
                            title: active > 0 ? '${active.toInt()}' : '',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          PieChartSectionData(
                            value: idle <= 0 ? 0.001 : idle,
                            color: const Color(0xFF0284C7),
                            radius: 42,
                            title: idle > 0 ? '${idle.toInt()}' : '',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          PieChartSectionData(
                            value: freeSlots <= 0 ? 0.001 : freeSlots,
                            color: const Color(0xFFE2E8F0),
                            radius: 40,
                            title: freeSlots > 0 ? '${freeSlots.toInt()}' : '',
                            titleStyle: const TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _LegendItem(
                  color: const Color(0xFF10B981),
                  label: 'Ativas: ${active.toInt()}',
                ),
                _LegendItem(
                  color: const Color(0xFF0284C7),
                  label: 'Ociosas: ${idle.toInt()}',
                ),
                _LegendItem(
                  color: const Color(0xFFCBD5E1),
                  label: 'Livres: ${freeSlots.toInt()}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubsystemUtilizationBarCard({
    required Map<String, dynamic>? db,
    required Map<String, dynamic>? jvm,
  }) {
    final active = (db?['activeConnections'] as num?)?.toDouble() ?? 0.0;
    final maxPool = (db?['maximumPoolSize'] as num?)?.toDouble() ?? 25.0;
    final poolPct = maxPool > 0
        ? ((active / maxPool) * 100.0).clamp(0.0, 100.0)
        : 0.0;
    final heapPct = ((jvm?['memoryUsedPercent'] as num?) ?? 0.0)
        .toDouble()
        .clamp(0.0, 100.0);
    final sysCpuPct = ((jvm?['systemCpuPercent'] as num?) ?? 0.0)
        .toDouble()
        .clamp(0.0, 100.0);
    final procCpuPct = ((jvm?['processCpuPercent'] as num?) ?? 0.0)
        .toDouble()
        .clamp(0.0, 100.0);
    final hostRamPct = ((jvm?['hostMemoryUsedPercent'] as num?) ?? 0.0)
        .toDouble()
        .clamp(0.0, 100.0);

    final bars = [
      ('Pool Hikari', poolPct, const Color(0xFF0284C7)),
      ('Heap JVM', heapPct, const Color(0xFF8B5CF6)),
      ('CPU Sist.', sysCpuPct, AdminGeralTheme.goldMetallic),
      ('CPU JVM', procCpuPct, const Color(0xFF10B981)),
      if (hostRamPct > 0) ('RAM Host', hostRamPct, const Color(0xFF6366F1)),
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comparativo Instantâneo de Utilização por Subsistema (%)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 185,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  gridData: const FlGridData(
                    show: true,
                    horizontalInterval: 25,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, idx, rod, rodIdx) {
                        final item = bars[group.x.toInt()];
                        return BarTooltipItem(
                          '${item.$1}: ${rod.toY.toStringAsFixed(1)}%',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
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
                        reservedSize: 36,
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
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= bars.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              bars[idx].$1,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(bars.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: bars[i].$2,
                          width: 24,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          color: bars[i].$3,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDbCard(Map<String, dynamic>? db) {
    final status = db?['status']?.toString() ?? 'DOWN';
    final pingMs = db?['pingMs']?.toString() ?? '-';
    final poolName = db?['poolName']?.toString() ?? 'HikariPool';
    final active = (db?['activeConnections'] as num?)?.toInt() ?? 0;
    final idle = (db?['idleConnections'] as num?)?.toInt() ?? 0;
    final total = (db?['totalConnections'] as num?)?.toInt() ?? 0;
    final maxPool = (db?['maximumPoolSize'] as num?)?.toInt() ?? 25;
    final awaiting = (db?['threadsAwaitingConnection'] as num?)?.toInt() ?? 0;

    final poolUsage = maxPool > 0 ? (active / maxPool).clamp(0.0, 1.0) : 0.0;
    final usageColor = poolUsage > 0.8
        ? Colors.red
        : (poolUsage > 0.5 ? AdminGeralTheme.goldMetallic : Colors.green);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storage_rounded, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Text(
                      'Banco de Dados & HikariCP',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                AnimatedRadialGauge(
                  percent: poolUsage,
                  color: usageColor,
                  centerLabel: '${(poolUsage * 100).toStringAsFixed(0)}%',
                  subtitle: 'Pool',
                  radius: 30,
                  lineWidth: 6,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _metricRow('Latência Ping', '$pingMs ms'),
                      _metricRow('Nome do Pool', poolName),
                      _metricRow(
                        'Conexões Ativas',
                        '$active / Total: $total (Max: $maxPool)',
                      ),
                      _metricRow('Conexões Ociosas (Idle)', '$idle'),
                      _metricRow('Threads Aguardando Conexão', '$awaiting'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Utilização do Pool: ${(poolUsage * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: poolUsage,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(usageColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJvmCard(Map<String, dynamic>? jvm) {
    final maxMb = (jvm?['jvmMaxMemoryMb'] as num?)?.toInt() ?? 0;
    final usedMb = (jvm?['jvmUsedMemoryMb'] as num?)?.toInt() ?? 0;
    final freeMb = (jvm?['jvmFreeMemoryMb'] as num?)?.toInt() ?? 0;
    final usedPct = (jvm?['memoryUsedPercent'] as num?)?.toDouble() ?? 0.0;
    final processors =
        (jvm?['logicalProcessors'] ?? jvm?['availableProcessors'])?.toString() ??
        '-';
    final sysCpu = jvm?['systemCpuPercent'];
    final jvmThreads = jvm?['jvmActiveThreads'];
    final uptime = _formatUptime(jvm?['uptimeSeconds']);

    final memFraction = (usedPct / 100.0).clamp(0.0, 1.0);
    final memColor = usedPct > 85
        ? Colors.red
        : (usedPct > 70
              ? AdminGeralTheme.goldMetallic
              : const Color(0xFF8B5CF6));

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.memory_rounded, color: Color(0xFF8B5CF6)),
                    SizedBox(width: 8),
                    Text(
                      'Recursos da JVM & Host',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                _statusBadge(usedPct > 90 ? 'DEGRADED' : 'UP'),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                AnimatedRadialGauge(
                  percent: memFraction,
                  color: memColor,
                  centerLabel: '${usedPct.toStringAsFixed(0)}%',
                  subtitle: 'Heap',
                  radius: 30,
                  lineWidth: 6,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _metricRow(
                        'Memória Usada (Heap)',
                        '$usedMb MB / $maxMb MB',
                      ),
                      _metricRow('Memória Livre', '$freeMb MB'),
                      _metricRow(
                        'Threads CPU Hardware (vCPU)',
                        '$processors vCPUs',
                      ),
                      if (jvmThreads != null)
                        _metricRow('Threads Java (JVM)', '$jvmThreads ativas'),
                      if (sysCpu != null)
                        _metricRow('Uso CPU Sistema', '$sysCpu%'),
                      _metricRow('Tempo em Atividade (Uptime)', uptime),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Uso de Heap: ${usedPct.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: memFraction),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, animatedValue, _) {
                  return LinearProgressIndicator(
                    value: animatedValue.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(memColor),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiCard(Map<String, dynamic>? ai) {
    final status = ai?['status']?.toString() ?? 'NOT_CONFIGURED';
    final service = ai?['service']?.toString() ?? 'Google Gemini AI';
    final model = ai?['model']?.toString() ?? '-';
    final providerUrl = ai?['providerUrl']?.toString() ?? 'default';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: AdminGeralTheme.goldMetallic,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Integração de IA Externa',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 14),
            _metricRow('Provedor', service),
            _metricRow('Modelo Ativo', model),
            _metricRow('Endpoint Provider', providerUrl),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFFB45309),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Geração de exercícios e explicações pedagógicas operando via Google Gemini.',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppCard(Map<String, dynamic>? app) {
    final name = app?['applicationName']?.toString() ?? 'Duolinfo Backend';
    final javaVer = app?['javaVersion']?.toString() ?? '-';
    final springVer = app?['springBootVersion']?.toString() ?? '-';
    final currTime =
        app?['currentTime']?.toString().replaceFirst('T', ' ') ?? '-';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF4F46E5)),
                    SizedBox(width: 8),
                    Text(
                      'Versão & Informações',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                _statusBadge('UP'),
              ],
            ),
            const SizedBox(height: 14),
            _metricRow('Aplicação', name),
            _metricRow('Versão do Java', javaVer),
            _metricRow('Spring Boot', springVer),
            _metricRow('Horário do Servidor', currTime),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF4F46E5),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ambiente seguro com Spring Security, Correlation IDs e Spring Cache ativos.',
                      style: TextStyle(
                        color: Color(0xFF3730A3),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthSamplePoint {
  const _HealthSamplePoint({
    required this.label,
    required this.heapPct,
    required this.cpuPct,
    required this.poolPct,
    required this.pingMs,
  });

  final String label;
  final double heapPct;
  final double cpuPct;
  final double poolPct;
  final double pingMs;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
