import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/supported_languages.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/ui/mascot/mascot.dart';
import '../../../../../core/ui/motion_kit.dart';
import '../responsive_layout.dart';

class AdminPerformanceDashboardView extends StatefulWidget {
  const AdminPerformanceDashboardView({
    super.key,
    this.onOpenSystemHealth,
    this.performanceLoader,
  });

  final VoidCallback? onOpenSystemHealth;
  final Future<Map<String, dynamic>> Function()? performanceLoader;

  @override
  State<AdminPerformanceDashboardView> createState() =>
      _AdminPerformanceDashboardViewState();
}

class _AdminPerformanceDashboardViewState
    extends State<AdminPerformanceDashboardView> {
  final Dio _dio = ApiClient().dio;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _perfData;
  bool _autoRefresh = false;
  Timer? _autoRefreshTimer;
  int _selectedSubTab = 0; // 0: Tempo Real, 1: Rede & JVM, 2: Ecossistema
  int _touchedPieIndex = -1;
  int _touchedProfileIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadPerformance();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoRefresh(bool enabled) {
    setState(() {
      _autoRefresh = enabled;
      _autoRefreshTimer?.cancel();
      if (_autoRefresh) {
        _autoRefreshTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => _loadPerformance(isBackground: true),
        );
      }
    });
  }

  Future<void> _loadPerformance({bool isBackground = false}) async {
    if (!isBackground && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final Map<String, dynamic> data;
      if (widget.performanceLoader != null) {
        data = await widget.performanceLoader!.call();
      } else {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/admin/system/performance',
        );
        data = Map<String, dynamic>.from(response.data ?? const {});
      }
      if (!mounted) return;
      setState(() {
        _perfData = data;
        _errorMessage = null;
      });
    } on DioException catch (e) {
      if (!mounted || isBackground) return;
      setState(() {
        _errorMessage =
            e.response?.data?['message']?.toString() ??
            'Não foi possível carregar os indicadores de performance (${e.message}).';
      });
    } catch (e) {
      if (!mounted || isBackground) return;
      setState(() {
        _errorMessage = 'Erro ao ler telemetria do servidor: $e';
      });
    } finally {
      if (mounted && !isBackground) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatUptime(num? seconds) {
    if (seconds == null) return '-';
    final s = seconds.toInt();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final rem = s % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${rem}s';
    return '${rem}s';
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'UP':
        return const Color(0xFF10B981);
      case 'DEGRADED':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is List) {
      return raw.map(_asMap).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final perf = _perfData;
    final status = perf?['overallStatus']?.toString() ?? 'UP';
    final uptime = perf?['uptimeSeconds'] as num?;
    final http = _asMap(perf?['httpMetrics']);
    final jvm = _asMap(perf?['jvmMetrics']);
    final pool = _asMap(perf?['databasePool']);
    final realtime = _asMap(perf?['realtimeMetrics']);
    final history = _asMapList(perf?['telemetryHistory']);
    final langBreakdown = _asMapList(perf?['languageBreakdown']);
    final profiles = _asMap(perf?['profileDistribution']);
    final audits = _asMap(perf?['auditSeverityDistribution']);

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredReveal(
            index: 0,
            withScale: true,
            child: Container(
              padding: responsiveBannerPadding(context),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E3A8A),
                    Color(0xFF4338CA),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.34),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 14,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.query_stats_rounded,
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
                                  'Centro de Performance & FLChart',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      status,
                                    ).withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: _statusColor(status),
                                    ),
                                  ),
                                  child: Text(
                                    '$status • Uptime ${_formatUptime(uptime)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Métricas reais em tempo real de HTTP, Latência P95, Memória JVM, CPU, HikariCP e distribuição nos 6 idiomas oficiais.',
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
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Ao vivo (5s)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Switch(
                              value: _autoRefresh,
                              onChanged: _toggleAutoRefresh,
                              activeThumbColor: const Color(0xFF34D399),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onOpenSystemHealth != null)
                        OutlinedButton.icon(
                          onPressed: widget.onOpenSystemHealth,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                          icon: const Icon(
                            Icons.monitor_heart_rounded,
                            size: 18,
                          ),
                          label: const Text('Saúde Detalhada'),
                        ),
                      FilledButton.icon(
                        onPressed: () => _loadPerformance(),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E3A8A),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Capturar Amostra'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _loadPerformance(),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),

          if (_isLoading && perf == null) ...[
            const MascotLoader(
              message: 'Coletando telemetria em tempo real...',
              state: MascotState.intense,
              compact: true,
              mascotSize: 60,
              showProgressBar: false,
              accentColor: Color(0xFFD97706),
            ),
            const SizedBox(height: 12),
            const AppShimmerDashboardLoader(cardCount: 4),
          ] else if (perf != null) ...[
            // Navegação interna da suíte de monitoramento
            StaggeredReveal(
              index: 1,
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _SubTabPill(
                    icon: Icons.speed_rounded,
                    label: 'Visão Tempo Real',
                    selected: _selectedSubTab == 0,
                    onTap: () => setState(() => _selectedSubTab = 0),
                  ),
                  _SubTabPill(
                    icon: Icons.memory_rounded,
                    label: 'JVM, CPU & HTTP',
                    selected: _selectedSubTab == 1,
                    onTap: () => setState(() => _selectedSubTab = 1),
                  ),
                  _SubTabPill(
                    icon: Icons.public_rounded,
                    label: '6 Idiomas & Auditoria',
                    selected: _selectedSubTab == 2,
                    onTap: () => setState(() => _selectedSubTab = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // KPIs Animados principais
            _buildKpiGrid(context, http, jvm, pool, realtime),
            const SizedBox(height: 20),

            MotionSectionSwitcher(
              child: KeyedSubtree(
                key: ValueKey(_selectedSubTab),
                child: _buildSubTabContent(
                  context,
                  history: history,
                  http: http,
                  jvm: jvm,
                  pool: pool,
                  langBreakdown: langBreakdown,
                  profiles: profiles,
                  audits: audits,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiGrid(
    BuildContext context,
    Map<String, dynamic> http,
    Map<String, dynamic> jvm,
    Map<String, dynamic> pool,
    Map<String, dynamic> realtime,
  ) {
    final totalReqs = (http['totalRequests'] as num?) ?? 0;
    final avgMs = (http['avgLatencyMs'] as num?) ?? 0;
    final p95Ms = (http['p95LatencyMs'] as num?) ?? 0;
    final heapPct = ((jvm['heapUsedPercent'] as num?) ?? 0).toDouble();
    final heapUsed = (jvm['heapUsedMb'] as num?) ?? 0;
    final heapMax = (jvm['heapMaxMb'] as num?) ?? 0;
    final cpuPct = ((jvm['processCpuPercent'] as num?) ?? 0).toDouble();
    final threads = (jvm['threadCount'] as num?) ?? 0;
    final dbPing = (pool['pingMs'] as num?) ?? 0;
    final activeConn = (pool['activeConnections'] as num?) ?? 0;
    final maxConn = (pool['maximumPoolSize'] as num?) ?? 10;
    final sseUsers = (realtime['sseConnectedUsers'] as num?) ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1060
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final spacing = 14.0;
        final width = (constraints.maxWidth - (spacing * (cols - 1))) / cols;

        final cards = [
          _TelemetryGaugeCard(
            title: 'Tráfego HTTP',
            metricValue: totalReqs,
            metricSuffix: ' reqs',
            subtitle:
                'Média ${avgMs.toStringAsFixed(1)}ms • P95 ${p95Ms.toStringAsFixed(1)}ms',
            percent: (100 - ((http['errorRatePercent'] as num?) ?? 0)) / 100.0,
            centerText:
                '${(100 - ((http['errorRatePercent'] as num?) ?? 0)).toStringAsFixed(0)}%',
            centerSub: 'Sucesso',
            color: const Color(0xFF2563EB),
            icon: Icons.http_rounded,
          ),
          _TelemetryGaugeCard(
            title: 'Memória JVM Heap',
            metricValue: heapUsed,
            metricSuffix: ' MB',
            subtitle: 'Alocado de $heapMax MB • GC ${jvm['gcCount'] ?? 0}x',
            percent: (heapPct / 100.0).clamp(0.0, 1.0),
            centerText: '${heapPct.toStringAsFixed(0)}%',
            centerSub: 'Heap',
            color: heapPct > 85
                ? const Color(0xFFDC2626)
                : const Color(0xFF7C3AED),
            icon: Icons.memory_rounded,
          ),
          _TelemetryGaugeCard(
            title: 'CPU & Threads JVM',
            metricValue: threads,
            metricSuffix: ' threads',
            subtitle:
                '${jvm['availableProcessors'] ?? '-'} núcleos • Pico ${jvm['peakThreadCount'] ?? '-'}',
            percent: (cpuPct / 100.0).clamp(0.0, 1.0),
            centerText: '${cpuPct.toStringAsFixed(1)}%',
            centerSub: 'CPU',
            color: const Color(0xFFD97706),
            icon: Icons.speed_rounded,
          ),
          _TelemetryGaugeCard(
            title: 'PostgreSQL & SSE Live',
            metricValue: dbPing,
            metricDecimals: 1,
            metricSuffix: ' ms',
            subtitle: 'Pool $activeConn/$maxConn ativas • $sseUsers SSE ativos',
            percent: maxConn > 0 ? (activeConn / maxConn).clamp(0.0, 1.0) : 0.0,
            centerText: '$activeConn',
            centerSub: 'Pool',
            color: const Color(0xFF059669),
            icon: Icons.storage_rounded,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            cards.length,
            (i) => SizedBox(
              width: width,
              child: StaggeredReveal(index: i + 1, child: cards[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubTabContent(
    BuildContext context, {
    required List<Map<String, dynamic>> history,
    required Map<String, dynamic> http,
    required Map<String, dynamic> jvm,
    required Map<String, dynamic> pool,
    required List<Map<String, dynamic>> langBreakdown,
    required Map<String, dynamic> profiles,
    required Map<String, dynamic> audits,
  }) {
    switch (_selectedSubTab) {
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLatencyLineChartCard(context, history),
            const SizedBox(height: 18),
            _buildResourceGaugesAndPoolCard(context, http, jvm, pool),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLanguagesBarChartCard(context, langBreakdown),
            const SizedBox(height: 18),
            _buildProfileAndAuditPies(context, profiles, audits),
          ],
        );
      case 0:
      default:
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            if (!isWide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCpuHeapLineChartCard(context, history),
                  const SizedBox(height: 16),
                  _buildLatencyLineChartCard(context, history),
                  const SizedBox(height: 16),
                  _buildHttpStatusPieCard(context, http),
                  const SizedBox(height: 16),
                  _buildLanguagesBarChartCard(context, langBreakdown),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildCpuHeapLineChartCard(context, history),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildHttpStatusPieCard(context, http),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildLatencyLineChartCard(context, history),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildLanguagesBarChartCard(
                        context,
                        langBreakdown,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
    }
  }

  Widget _buildCpuHeapLineChartCard(
    BuildContext context,
    List<Map<String, dynamic>> history,
  ) {
    final heapSpots = <FlSpot>[];
    final cpuSpots = <FlSpot>[];
    final labels = <String>[];

    for (var i = 0; i < history.length; i++) {
      final point = history[i];
      final heap = ((point['heapUsedPercent'] as num?) ?? 0).toDouble().clamp(
        0.0,
        100.0,
      );
      final cpu = ((point['processCpuPercent'] as num?) ?? 0).toDouble().clamp(
        0.0,
        100.0,
      );
      heapSpots.add(FlSpot(i.toDouble(), heap));
      cpuSpots.add(FlSpot(i.toDouble(), cpu));
      labels.add(point['label']?.toString() ?? '#$i');
    }

    return InteractiveMotionCard(
      padding: const EdgeInsets.all(20),
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
                  Icon(Icons.show_chart_rounded, color: Color(0xFF7C3AED)),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Curva JVM Heap % vs CPU Processo (%)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _ChartLegendDot(color: Color(0xFF7C3AED), label: 'Heap %'),
                  _ChartLegendDot(color: Color(0xFFF59E0B), label: 'CPU %'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Janela móvel real das últimas ${history.length} amostras capturadas no backend.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 230,
            child: heapSpots.isEmpty
                ? const Center(child: Text('Aguardando primeira amostra...'))
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
                            reservedSize: 24,
                            interval: (labels.length / 4)
                                .clamp(1, 10)
                                .toDouble(),
                            getTitlesWidget: (val, _) {
                              final idx = val.round();
                              if (idx < 0 || idx >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  labels[idx],
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
                            final idx = s.x.round();
                            final timeLabel = idx >= 0 && idx < labels.length
                                ? labels[idx]
                                : '';
                            final name = s.barIndex == 0 ? 'Heap' : 'CPU';
                            return LineTooltipItem(
                              '$timeLabel • $name: ${s.y.toStringAsFixed(1)}%',
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
                          color: const Color(0xFF7C3AED),
                          barWidth: 3,
                          dotData: FlDotData(show: heapSpots.length <= 8),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF7C3AED).withValues(alpha: 0.28),
                                const Color(0xFF7C3AED).withValues(alpha: 0.02),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        LineChartBarData(
                          spots: cpuSpots,
                          isCurved: cpuSpots.length > 2,
                          color: const Color(0xFFF59E0B),
                          barWidth: 3,
                          dotData: FlDotData(show: cpuSpots.length <= 8),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.09),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 350),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatencyLineChartCard(
    BuildContext context,
    List<Map<String, dynamic>> history,
  ) {
    final avgSpots = <FlSpot>[];
    final p95Spots = <FlSpot>[];
    final dbSpots = <FlSpot>[];
    final labels = <String>[];
    double maxY = 20;

    for (var i = 0; i < history.length; i++) {
      final p = history[i];
      final avg = ((p['avgLatencyMs'] as num?) ?? 0).toDouble();
      final p95 = ((p['p95LatencyMs'] as num?) ?? 0).toDouble();
      final db = ((p['dbPingMs'] as num?) ?? 0).toDouble();
      if (avg > maxY) maxY = avg;
      if (p95 > maxY) maxY = p95;
      if (db > maxY) maxY = db;
      avgSpots.add(FlSpot(i.toDouble(), avg));
      p95Spots.add(FlSpot(i.toDouble(), p95));
      dbSpots.add(FlSpot(i.toDouble(), db));
      labels.add(p['label']?.toString() ?? '#$i');
    }

    return InteractiveMotionCard(
      padding: const EdgeInsets.all(20),
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
                  Icon(Icons.bolt_rounded, color: Color(0xFF06B6D4)),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Latência HTTP Média, P95 & Ping DB (ms)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _ChartLegendDot(color: Color(0xFF06B6D4), label: 'Média'),
                  _ChartLegendDot(color: Color(0xFFEC4899), label: 'P95'),
                  _ChartLegendDot(color: Color(0xFF10B981), label: 'DB Ping'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: avgSpots.isEmpty
                ? const Center(
                    child: Text('Aguardando amostras de latência...'),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: (maxY * 1.25).ceilToDouble().clamp(10, 100000),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.4),
                          strokeWidth: 1,
                        ),
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
                            reservedSize: 42,
                            getTitlesWidget: (v, _) => Text(
                              '${v.toInt()}ms',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: (labels.length / 4)
                                .clamp(1, 10)
                                .toDouble(),
                            getTitlesWidget: (val, _) {
                              final idx = val.round();
                              if (idx < 0 || idx >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  labels[idx],
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
                            final series = switch (s.barIndex) {
                              0 => 'HTTP Média',
                              1 => 'HTTP P95',
                              _ => 'DB Ping',
                            };
                            return LineTooltipItem(
                              '$series: ${s.y.toStringAsFixed(1)} ms',
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
                          spots: avgSpots,
                          isCurved: avgSpots.length > 2,
                          color: const Color(0xFF06B6D4),
                          barWidth: 2.8,
                          dotData: FlDotData(show: avgSpots.length <= 8),
                        ),
                        LineChartBarData(
                          spots: p95Spots,
                          isCurved: p95Spots.length > 2,
                          color: const Color(0xFFEC4899),
                          barWidth: 2.8,
                          dotData: FlDotData(show: p95Spots.length <= 8),
                        ),
                        LineChartBarData(
                          spots: dbSpots,
                          isCurved: dbSpots.length > 2,
                          color: const Color(0xFF10B981),
                          barWidth: 2.4,
                          dotData: FlDotData(show: dbSpots.length <= 8),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 350),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHttpStatusPieCard(
    BuildContext context,
    Map<String, dynamic> http,
  ) {
    final s2xx = ((http['success2xx'] as num?) ?? 0).toDouble();
    final c4xx = ((http['client4xx'] as num?) ?? 0).toDouble();
    final s5xx = ((http['server5xx'] as num?) ?? 0).toDouble();
    final total = s2xx + c4xx + s5xx;

    final entries = <_PieSliceSpec>[
      _PieSliceSpec('Sucesso (2xx/3xx)', s2xx, const Color(0xFF10B981)),
      _PieSliceSpec('Cliente (4xx)', c4xx, const Color(0xFFF59E0B)),
      _PieSliceSpec('Servidor (5xx)', s5xx, const Color(0xFFEF4444)),
    ];

    return InteractiveMotionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Respostas HTTP por Status',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: total <= 0
                ? const Center(
                    child: Text('Sem requisições HTTP contabilizadas ainda.'),
                  )
                : PieChart(
                    PieChartData(
                      centerSpaceRadius: 42,
                      sectionsSpace: 3,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _touchedPieIndex = -1;
                              return;
                            }
                            _touchedPieIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: List.generate(entries.length, (i) {
                        final slice = entries[i];
                        final isTouched = i == _touchedPieIndex;
                        final pct = (slice.value / total) * 100;
                        return PieChartSectionData(
                          value: slice.value <= 0 ? 0.001 : slice.value,
                          color: slice.color,
                          radius: isTouched ? 58 : 48,
                          title: slice.value > 0
                              ? '${pct.toStringAsFixed(0)}%'
                              : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        );
                      }),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: e.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.label,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  Text(
                    '${e.value.toInt()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagesBarChartCard(
    BuildContext context,
    List<Map<String, dynamic>> rawBreakdown,
  ) {
    final mapByLang = <String, Map<String, dynamic>>{
      for (final row in rawBreakdown)
        SupportedLanguages.normalizeOrDefault(row['language']?.toString()): row,
    };

    double maxVal = 4;
    for (final lang in kSupportedLanguages) {
      final row = mapByLang[lang] ?? const {};
      final students = ((row['students'] as num?) ?? 0).toDouble();
      final classes = ((row['classes'] as num?) ?? 0).toDouble();
      final exercises = ((row['exercises'] as num?) ?? 0).toDouble();
      for (final val in [students, classes, exercises]) {
        if (val > maxVal) maxVal = val;
      }
    }

    return InteractiveMotionCard(
      padding: const EdgeInsets.all(20),
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
                  Icon(Icons.bar_chart_rounded, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Demanda nos 6 Idiomas Oficiais (FLChart)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _ChartLegendDot(color: Color(0xFF2563EB), label: 'Alunos'),
                  _ChartLegendDot(color: Color(0xFF10B981), label: 'Turmas'),
                  _ChartLegendDot(
                    color: Color(0xFF8B5CF6),
                    label: 'Exercícios',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                maxY: (maxVal * 1.25).ceilToDouble().clamp(4, 100000),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final lang = kSupportedLanguages[group.x.toInt()];
                      final series = switch (rodIndex) {
                        0 => 'Alunos',
                        1 => 'Turmas',
                        _ => 'Exercícios',
                      };
                      return BarTooltipItem(
                        '$lang\n$series: ${rod.toY.toInt()}',
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
                      reservedSize: 32,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= kSupportedLanguages.length) {
                          return const SizedBox.shrink();
                        }
                        final lang = kSupportedLanguages[idx];
                        final meta = SupportedLanguages.metaFor(lang);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${meta.shortCode}•${lang.substring(0, 3)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: meta.color,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(kSupportedLanguages.length, (index) {
                  final lang = kSupportedLanguages[index];
                  final row = mapByLang[lang] ?? const {};
                  final students = ((row['students'] as num?) ?? 0).toDouble();
                  final classes = ((row['classes'] as num?) ?? 0).toDouble();
                  final exercises = ((row['exercises'] as num?) ?? 0)
                      .toDouble();
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: students,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        color: const Color(0xFF2563EB),
                      ),
                      BarChartRodData(
                        toY: classes,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        color: const Color(0xFF10B981),
                      ),
                      BarChartRodData(
                        toY: exercises,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        color: const Color(0xFF8B5CF6),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceGaugesAndPoolCard(
    BuildContext context,
    Map<String, dynamic> http,
    Map<String, dynamic> jvm,
    Map<String, dynamic> pool,
  ) {
    final heapPct = ((jvm['heapUsedPercent'] as num?) ?? 0).toDouble() / 100.0;
    final poolPct =
        ((pool['utilizationPercent'] as num?) ?? 0).toDouble() / 100.0;
    final errPct = ((http['errorRatePercent'] as num?) ?? 0).toDouble() / 100.0;

    return InteractiveMotionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pressão de Recursos & Pool de Conexões',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _GaugeDetailRow(
            label:
                'Memória Heap (${jvm['heapUsedMb'] ?? 0} / ${jvm['heapMaxMb'] ?? 0} MB)',
            percent: heapPct,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 12),
          _GaugeDetailRow(
            label:
                'Conexões Ativas no Pool Hikari (${pool['activeConnections'] ?? 0} / ${pool['maximumPoolSize'] ?? 10})',
            percent: poolPct,
            color: const Color(0xFF059669),
          ),
          const SizedBox(height: 12),
          _GaugeDetailRow(
            label:
                'Taxa de Erros HTTP 4xx/5xx (${((http['errorRatePercent'] as num?) ?? 0).toStringAsFixed(2)}%)',
            percent: errPct,
            color: const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAndAuditPies(
    BuildContext context,
    Map<String, dynamic> profiles,
    Map<String, dynamic> audits,
  ) {
    final profileSlices = [
      _PieSliceSpec(
        'Alunos',
        ((profiles['STUDENT'] as num?) ?? 0).toDouble(),
        const Color(0xFF2563EB),
      ),
      _PieSliceSpec(
        'Professores',
        ((profiles['TEACHER'] as num?) ?? 0).toDouble(),
        const Color(0xFF7C3AED),
      ),
      _PieSliceSpec(
        'Administradores',
        ((profiles['ADMIN'] as num?) ?? 0).toDouble(),
        const Color(0xFFD97706),
      ),
      _PieSliceSpec(
        'Base (USER)',
        ((profiles['USER'] as num?) ?? 0).toDouble(),
        const Color(0xFF64748B),
      ),
    ];
    final profileTotal = profileSlices.fold<double>(
      0,
      (acc, e) => acc + e.value,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;
        final profileCard = InteractiveMotionCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Perfis na Plataforma',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: profileTotal <= 0
                    ? const Center(child: Text('Sem contas contabilizadas.'))
                    : PieChart(
                        PieChartData(
                          centerSpaceRadius: 38,
                          sectionsSpace: 3,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    response?.touchedSection == null) {
                                  _touchedProfileIndex = -1;
                                  return;
                                }
                                _touchedProfileIndex = response!
                                    .touchedSection!
                                    .touchedSectionIndex;
                              });
                            },
                          ),
                          sections: List.generate(profileSlices.length, (i) {
                            final slice = profileSlices[i];
                            final isTouched = i == _touchedProfileIndex;
                            return PieChartSectionData(
                              value: slice.value <= 0 ? 0.001 : slice.value,
                              color: slice.color,
                              radius: isTouched ? 56 : 46,
                              title: slice.value > 0
                                  ? '${slice.value.toInt()}'
                                  : '',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            );
                          }),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: profileSlices
                    .map(
                      (e) => _ChartLegendDot(
                        color: e.color,
                        label: '${e.label}: ${e.value.toInt()}',
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );

        final auditEntries = audits.entries.toList();
        final auditCard = InteractiveMotionCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Logs de Auditoria por Severidade',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (auditEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Nenhum evento auditado ainda.')),
                )
              else
                ...auditEntries.map((entry) {
                  final sev = entry.key.toUpperCase();
                  final count = (entry.value as num?)?.toInt() ?? 0;
                  final maxAudit = auditEntries.fold<int>(
                    1,
                    (m, item) => ((item.value as num?)?.toInt() ?? 0) > m
                        ? (item.value as num).toInt()
                        : m,
                  );
                  final color = sev == 'ERROR' || sev == 'CRITICAL'
                      ? const Color(0xFFDC2626)
                      : (sev == 'WARN'
                            ? const Color(0xFFD97706)
                            : const Color(0xFF2563EB));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GaugeDetailRow(
                      label: '$sev ($count eventos)',
                      percent: count / maxAudit,
                      color: color,
                    ),
                  );
                }),
            ],
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: profileCard),
              const SizedBox(width: 16),
              Expanded(child: auditCard),
            ],
          );
        }
        return Column(
          children: [profileCard, const SizedBox(height: 16), auditCard],
        );
      },
    );
  }
}

class _SubTabPill extends StatelessWidget {
  const _SubTabPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? const Color(0xFF1E3A8A)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelemetryGaugeCard extends StatelessWidget {
  const _TelemetryGaugeCard({
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AnimatedRadialGauge(
            percent: percent,
            color: color,
            centerLabel: centerText,
            subtitle: centerSub,
            radius: 34,
            lineWidth: 7,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedMetricCounter(
                  value: metricValue,
                  decimals: metricDecimals,
                  suffix: metricSuffix,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
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

class _GaugeDetailRow extends StatelessWidget {
  const _GaugeDetailRow({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        AnimatedLinearGauge(
          percent: percent,
          progressColor: color,
          lineHeight: 10,
        ),
      ],
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
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

class _PieSliceSpec {
  const _PieSliceSpec(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}
