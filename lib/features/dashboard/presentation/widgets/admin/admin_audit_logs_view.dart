import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/network/api_client.dart';
import '../responsive_layout.dart';

class AdminAuditLogsView extends StatefulWidget {
  const AdminAuditLogsView({super.key});

  @override
  State<AdminAuditLogsView> createState() => _AdminAuditLogsViewState();
}

class _AdminAuditLogsViewState extends State<AdminAuditLogsView> {
  final Dio _dio = ApiClient().dio;

  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _logs = [];
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalElements = 0;
  final int _pageSize = 15;

  String _selectedCategory = 'ALL';
  String _selectedSeverity = 'ALL';
  String _selectedResult = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'ALL',
    'AUTH',
    'USER',
    'ADMIN',
    'SECURITY',
    'CATALOG',
    'DOCUMENT',
    'SYSTEM',
  ];

  final List<String> _severities = ['ALL', 'INFO', 'WARN', 'ERROR'];

  final List<String> _results = ['ALL', 'SUCCESS', 'FAILURE', 'ERROR'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = <String, dynamic>{
        'page': _currentPage,
        'size': _pageSize,
      };

      if (_selectedCategory != 'ALL') {
        queryParams['category'] = _selectedCategory;
      }
      if (_selectedSeverity != 'ALL') {
        queryParams['severity'] = _selectedSeverity;
      }
      if (_selectedResult != 'ALL') {
        queryParams['result'] = _selectedResult;
      }
      if (_searchController.text.trim().isNotEmpty) {
        queryParams['search'] = _searchController.text.trim();
      }

      final response = await _dio.get(
        '/api/admin/logs',
        queryParameters: queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final content = (data['content'] as List<dynamic>?) ?? [];

      if (!mounted) return;
      setState(() {
        _logs = content.cast<Map<String, dynamic>>();
        _totalPages = (data['totalPages'] as int?) ?? 1;
        _totalElements = (data['totalElements'] as int?) ?? 0;
        _currentPage = (data['currentPage'] as int?) ?? 0;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            e.response?.data?['message']?.toString() ??
            'Falha ao carregar registros de auditoria (${e.message}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro inesperado: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _severityColor(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'ERROR':
        return const Color(0xFFEF4444);
      case 'WARN':
        return const Color(0xFFF59E0B);
      case 'INFO':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Color _categoryColor(String? category) {
    switch (category?.toUpperCase()) {
      case 'AUTH':
        return const Color(0xFF8B5CF6);
      case 'SECURITY':
        return const Color(0xFFEA580C);
      case 'ADMIN':
        return const Color(0xFF4F46E5);
      case 'USER':
        return const Color(0xFF0D9488);
      case 'CATALOG':
        return const Color(0xFF10B981);
      case 'DOCUMENT':
        return const Color(0xFF0284C7);
      case 'SYSTEM':
      default:
        return const Color(0xFF64748B);
    }
  }

  void _showLogDetailsDialog(Map<String, dynamic> log) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final timestamp =
            log['timestamp']?.toString().replaceFirst('T', ' ') ?? '-';
        final severity = log['severity']?.toString() ?? 'INFO';
        final category = log['category']?.toString() ?? 'SYSTEM';
        final action = log['action']?.toString() ?? '-';
        final actorEmail = log['actorEmail']?.toString() ?? '-';
        final actorRole = log['actorRole']?.toString() ?? '-';
        final result = log['result']?.toString() ?? 'SUCCESS';
        final clientIp = log['clientIp']?.toString() ?? '-';
        final correlationId = log['correlationId']?.toString() ?? '-';
        final details =
            log['details']?.toString() ?? 'Nenhum detalhe adicional informado.';
        final targetEntity = log['targetEntity']?.toString();
        final targetId = log['targetId']?.toString();

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _severityColor(severity).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _severityColor(severity)),
                ),
                child: Text(
                  severity,
                  style: TextStyle(
                    color: _severityColor(severity),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Data e Hora', timestamp),
                  _detailRow('Categoria', category),
                  _detailRow('Usuário / Ator', '$actorEmail ($actorRole)'),
                  _detailRow('Resultado', result),
                  if (targetEntity != null)
                    _detailRow(
                      'Alvo / Entidade',
                      '$targetEntity (ID: ${targetId ?? "-"})',
                    ),
                  _detailRow('IP de Origem', clientIp),
                  _detailRow('Correlation ID', correlationId),
                  const SizedBox(height: 14),
                  const Text(
                    'Detalhes & Contexto:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: SelectableText(
                      details,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Fechar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

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
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF334155),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
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
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.history_edu_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Central de Logs & Auditoria',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rastreamento completo e imutável de eventos de autenticação, operações administrativas e erros do sistema.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadLogs,
                  tooltip: 'Atualizar Logs',
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 20),

          // Filters Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros de Pesquisa',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search field
                      SizedBox(
                        width: isDesktop ? 260 : double.infinity,
                        height: 42,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar por ação, usuário, alvo...',
                            hintStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                          ),
                          onSubmitted: (_) {
                            setState(() => _currentPage = 0);
                            _loadLogs();
                          },
                        ),
                      ),

                      // Category Dropdown
                      DropdownButton<String>(
                        value: _selectedCategory,
                        underline: const SizedBox(),
                        items: _categories.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(
                              c == 'ALL' ? 'Todas Categorias' : c,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                              _currentPage = 0;
                            });
                            _loadLogs();
                          }
                        },
                      ),

                      // Severity Dropdown
                      DropdownButton<String>(
                        value: _selectedSeverity,
                        underline: const SizedBox(),
                        items: _severities.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(
                              s == 'ALL' ? 'Todas Severidades' : s,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedSeverity = val;
                              _currentPage = 0;
                            });
                            _loadLogs();
                          }
                        },
                      ),

                      // Result Dropdown
                      DropdownButton<String>(
                        value: _selectedResult,
                        underline: const SizedBox(),
                        items: _results.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text(
                              r == 'ALL' ? 'Todos Resultados' : r,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedResult = val;
                              _currentPage = 0;
                            });
                            _loadLogs();
                          }
                        },
                      ),

                      // Search Button
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _currentPage = 0);
                          _loadLogs();
                        },
                        icon: const Icon(Icons.filter_list_rounded, size: 16),
                        label: const Text('Filtrar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Error state
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

          // Loading state
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_logs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhum registro de auditoria encontrado com os filtros selecionados.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Table
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _logs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final severity = log['severity']?.toString() ?? 'INFO';
                    final category = log['category']?.toString() ?? 'SYSTEM';
                    final action = log['action']?.toString() ?? '-';
                    final actorEmail = log['actorEmail']?.toString() ?? '-';
                    final timestamp =
                        log['timestamp']?.toString().replaceFirst('T', ' ') ??
                        '-';
                    final result = log['result']?.toString() ?? 'SUCCESS';

                    return ListTile(
                      onTap: () => _showLogDetailsDialog(log),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _severityColor(
                            severity,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _severityColor(severity)),
                        ),
                        child: Text(
                          severity,
                          style: TextStyle(
                            color: _severityColor(severity),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _categoryColor(
                                category,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: _categoryColor(category),
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              action,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Por: $actorEmail • $timestamp',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            result == 'SUCCESS'
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: result == 'SUCCESS'
                                ? Colors.green
                                : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pagination Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: $_totalElements registros (Página ${_currentPage + 1} de $_totalPages)',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.navigate_before_rounded),
                      onPressed: _currentPage > 0
                          ? () {
                              setState(() => _currentPage--);
                              _loadLogs();
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigate_next_rounded),
                      onPressed: _currentPage + 1 < _totalPages
                          ? () {
                              setState(() => _currentPage++);
                              _loadLogs();
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
