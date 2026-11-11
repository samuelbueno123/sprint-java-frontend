import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/network/api_client.dart';
import '../responsive_layout.dart';

class AdminSystemHealthView extends StatefulWidget {
  const AdminSystemHealthView({super.key});

  @override
  State<AdminSystemHealthView> createState() => _AdminSystemHealthViewState();
}

class _AdminSystemHealthViewState extends State<AdminSystemHealthView> {
  final Dio _dio = ApiClient().dio;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _healthData;
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
      if (_autoRefresh) {
        _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          _loadHealth(isBackground: true);
        });
      } else {
        _autoRefreshTimer?.cancel();
      }
    });
  }

  Future<void> _loadHealth({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _dio.get('/api/admin/system/health');
      if (!mounted) return;
      setState(() {
        _healthData = response.data as Map<String, dynamic>;
        _errorMessage = null;
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
        return const Color(0xFFF59E0B);
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
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF064E3B),
                  Color(0xFF047857),
                  Color(0xFF059669),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF047857).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Monitoramento & Diagnóstico',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                        'Inspeção em tempo real de banco de dados, pool de conexões HikariCP, IA externa e recursos da JVM.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
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

          // Error banner
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
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_healthData != null) ...[
            // Grid of Health Cards
            GridView.count(
              crossAxisCount: isDesktop ? 2 : 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isDesktop ? 1.6 : 1.3,
              children: [
                // 1. Database & Connection Pool Card
                _buildDbCard(_healthData!['database'] as Map<String, dynamic>?),

                // 2. JVM & System Resources Card
                _buildJvmCard(
                  _healthData!['systemResources'] as Map<String, dynamic>?,
                ),

                // 3. External AI Integration Card
                _buildAiCard(
                  _healthData!['externalAi'] as Map<String, dynamic>?,
                ),

                // 4. Runtime & Application Info Card
                _buildAppCard(
                  _healthData!['application'] as Map<String, dynamic>?,
                ),
              ],
            ),
          ],
        ],
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
                Row(
                  children: [
                    const Icon(Icons.storage_rounded, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    const Text(
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
            const SizedBox(height: 12),
            _metricRow('Latência Ping', '$pingMs ms'),
            _metricRow('Nome do Pool', poolName),
            _metricRow(
              'Conexões Ativas',
              '$active / Total: $total (Max: $maxPool)',
            ),
            _metricRow('Conexões Ociosas (Idle)', '$idle'),
            _metricRow('Threads Aguardando Conexão', '$awaiting'),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Utilização do Pool: ${(poolUsage * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: poolUsage,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      poolUsage > 0.8
                          ? Colors.red
                          : (poolUsage > 0.5 ? Colors.amber : Colors.green),
                    ),
                  ),
                ),
              ],
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
    final processors = jvm?['availableProcessors']?.toString() ?? '-';
    final uptime = _formatUptime(jvm?['uptimeSeconds']);

    final memFraction = (usedPct / 100.0).clamp(0.0, 1.0);

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
                Row(
                  children: [
                    const Icon(Icons.memory_rounded, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 8),
                    const Text(
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
            const SizedBox(height: 12),
            _metricRow('Memória Usada (Heap)', '$usedMb MB / $maxMb MB'),
            _metricRow('Memória Livre', '$freeMb MB'),
            _metricRow('Processadores (vCPU)', processors),
            _metricRow('Tempo em Atividade (Uptime)', uptime),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uso de Heap: ${usedPct.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: memFraction,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      usedPct > 85
                          ? Colors.red
                          : (usedPct > 70
                                ? Colors.amber
                                : const Color(0xFF8B5CF6)),
                    ),
                  ),
                ),
              ],
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
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    const Text(
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
            const Spacer(),
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
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 8),
                    const Text(
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
            const Spacer(),
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
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
