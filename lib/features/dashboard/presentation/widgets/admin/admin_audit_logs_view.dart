import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/constants/app_feedback_widgets.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/theme/admin_geral_theme.dart';
import '../../../../../core/utils/file_download_helper.dart';
import '../responsive_layout.dart';

class AdminAuditLogsView extends StatefulWidget {
  const AdminAuditLogsView({super.key, this.dio});

  final Dio? dio;

  @override
  State<AdminAuditLogsView> createState() => _AdminAuditLogsViewState();
}

class _AdminAuditLogsViewState extends State<AdminAuditLogsView> {
  late final Dio _dio = widget.dio ?? ApiClient().dio;

  // 0 = Arquivos do Servidor (30 dias), 1 = Auditoria Estruturada (Banco)
  int _activeTab = 0;

  // --- Estado: Arquivos Separados (30 dias) ---
  bool _isLoadingFiles = false;
  bool _isLoadingFileContent = false;
  bool _isCleaningUp = false;
  String? _filesErrorMessage;

  int _retentionDays = 30;
  String _logDirectory = '';
  int _totalLogFiles = 0;
  int _totalLogBytes = 0;
  String _selectedChannel = 'ALL';
  List<Map<String, dynamic>> _logFiles = [];

  String? _selectedFileName;
  String _fileSeverityFilter = 'ALL';
  final TextEditingController _fileSearchController = TextEditingController();
  int _filePage = 0;
  final int _fileLimit = 80;
  int _fileTotalLines = 0;
  int _fileMatchedLines = 0;
  int _fileInfoCount = 0;
  int _fileWarnCount = 0;
  int _fileErrorCount = 0;
  List<Map<String, dynamic>> _fileEntries = [];

  // --- Estado: Auditoria Estruturada (BD) ---
  bool _auditLogsLoadedOnce = false;
  bool _isLoadingAuditLogs = false;
  String? _auditErrorMessage;

  List<Map<String, dynamic>> _auditLogs = [];
  int _auditPage = 0;
  int _auditTotalPages = 1;
  int _auditTotalElements = 0;
  final int _auditPageSize = 15;

  String _selectedCategory = 'ALL';
  String _selectedSeverity = 'ALL';
  String _selectedResult = 'ALL';
  final TextEditingController _auditSearchController = TextEditingController();

  static const List<String> _channels = [
    'ALL',
    'application',
    'errors',
    'security-audit',
  ];

  static const List<String> _categories = [
    'ALL',
    'AUTH',
    'USER',
    'ADMIN',
    'SECURITY',
    'CATALOG',
    'DOCUMENT',
    'SYSTEM',
  ];

  static const List<String> _severities = ['ALL', 'INFO', 'WARN', 'ERROR'];
  static const List<String> _results = ['ALL', 'SUCCESS', 'FAILURE', 'ERROR'];

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  @override
  void dispose() {
    _fileSearchController.dispose();
    _auditSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogFiles({bool keepSelection = true}) async {
    setState(() {
      _isLoadingFiles = true;
      _filesErrorMessage = null;
    });

    try {
      final queryParams = <String, dynamic>{};
      if (_selectedChannel != 'ALL') {
        queryParams['channel'] = _selectedChannel;
      }

      final response = await _dio.get(
        '/api/admin/logs/files',
        queryParameters: queryParams,
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawFiles = (data['files'] as List<dynamic>?) ?? const [];
      final files = rawFiles
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      String? nextSelection;
      if (keepSelection &&
          _selectedFileName != null &&
          files.any((f) => f['fileName'] == _selectedFileName)) {
        nextSelection = _selectedFileName;
      } else if (files.isNotEmpty) {
        nextSelection = files.first['fileName']?.toString();
      }

      if (!mounted) return;
      setState(() {
        _retentionDays = (data['retentionDays'] as num?)?.toInt() ?? 30;
        _logDirectory = data['logDirectory']?.toString() ?? '';
        _totalLogFiles = (data['totalFiles'] as num?)?.toInt() ?? files.length;
        _totalLogBytes = (data['totalSizeBytes'] as num?)?.toInt() ?? 0;
        _logFiles = files;
        _selectedFileName = nextSelection;
      });

      if (nextSelection != null) {
        await _loadSelectedFileContent();
      } else if (mounted) {
        setState(() {
          _fileEntries = [];
          _fileTotalLines = 0;
          _fileMatchedLines = 0;
          _fileInfoCount = 0;
          _fileWarnCount = 0;
          _fileErrorCount = 0;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _filesErrorMessage =
            e.response?.data?['message']?.toString() ??
            'Falha ao listar arquivos de log (${e.message}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _filesErrorMessage = 'Erro inesperado ao carregar arquivos: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingFiles = false);
      }
    }
  }

  Future<void> _loadSelectedFileContent() async {
    final fileName = _selectedFileName;
    if (fileName == null || fileName.isEmpty) return;

    setState(() {
      _isLoadingFileContent = true;
      _filesErrorMessage = null;
    });

    try {
      final queryParams = <String, dynamic>{
        'page': _filePage,
        'limit': _fileLimit,
      };
      if (_fileSeverityFilter != 'ALL') {
        queryParams['severity'] = _fileSeverityFilter;
      }
      final search = _fileSearchController.text.trim();
      if (search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get(
        '/api/admin/logs/files/${Uri.encodeComponent(fileName)}',
        queryParameters: queryParams,
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawEntries = (data['entries'] as List<dynamic>?) ?? const [];

      if (!mounted) return;
      setState(() {
        _fileTotalLines = (data['totalLines'] as num?)?.toInt() ?? 0;
        _fileMatchedLines = (data['matchedLines'] as num?)?.toInt() ?? 0;
        _fileInfoCount = (data['infoCount'] as num?)?.toInt() ?? 0;
        _fileWarnCount = (data['warnCount'] as num?)?.toInt() ?? 0;
        _fileErrorCount = (data['errorCount'] as num?)?.toInt() ?? 0;
        _fileEntries = rawEntries
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _filesErrorMessage =
            e.response?.data?['message']?.toString() ??
            'Falha ao ler arquivo $fileName (${e.message}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _filesErrorMessage = 'Erro inesperado ao ler arquivo: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingFileContent = false);
      }
    }
  }

  Future<void> _triggerRetentionCleanup() async {
    setState(() => _isCleaningUp = true);
    try {
      final response = await _dio.post('/api/admin/logs/files/cleanup');
      final data = Map<String, dynamic>.from(response.data as Map);
      final deleted = (data['deletedFiles'] as num?)?.toInt() ?? 0;
      final freed = (data['freedBytes'] as num?)?.toInt() ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deleted > 0
                  ? 'Retenção de $_retentionDays dias aplicada: $deleted arquivo(s) antigos removidos (${_formatBytes(freed)}).'
                  : 'Todos os arquivos já estão dentro da janela de $_retentionDays dias.',
            ),
          ),
        );
      }
      await _loadLogFiles(keepSelection: true);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(
              e.response?.data?['message']?.toString() ??
                  'Falha ao executar limpeza de retenção.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCleaningUp = false);
      }
    }
  }

  Future<void> _downloadLogFile(String fileName) async {
    try {
      final response = await _dio.get<List<int>>(
        '/api/admin/logs/files/${Uri.encodeComponent(fileName)}/download',
        options: Options(responseType: ResponseType.bytes),
      );
      final rawBytes = response.data ?? const <int>[];
      final bytes = Uint8List.fromList(rawBytes);
      final isGzip = fileName.toLowerCase().endsWith('.gz');
      final downloaded = await triggerBytesDownload(
        bytes: bytes,
        fileName: fileName,
        mimeType: isGzip ? 'application/gzip' : 'text/plain; charset=utf-8',
      );
      if (!downloaded && !isGzip) {
        await Clipboard.setData(
          ClipboardData(text: String.fromCharCodes(bytes)),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              downloaded
                  ? 'Download de $fileName iniciado (${_formatBytes(bytes.length)}).'
                  : 'Arquivo $fileName obtido (${_formatBytes(bytes.length)}).',
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(
              e.response?.data?['message']?.toString() ??
                  'Erro ao baixar $fileName.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAuditLogs() async {
    setState(() {
      _isLoadingAuditLogs = true;
      _auditErrorMessage = null;
      _auditLogsLoadedOnce = true;
    });

    try {
      final queryParams = <String, dynamic>{
        'page': _auditPage,
        'size': _auditPageSize,
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
      if (_auditSearchController.text.trim().isNotEmpty) {
        queryParams['search'] = _auditSearchController.text.trim();
      }

      final response = await _dio.get(
        '/api/admin/logs',
        queryParameters: queryParams,
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final content = (data['content'] as List<dynamic>?) ?? const [];

      if (!mounted) return;
      setState(() {
        _auditLogs = content
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _auditTotalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
        _auditTotalElements = (data['totalElements'] as num?)?.toInt() ?? 0;
        _auditPage = (data['currentPage'] as num?)?.toInt() ?? 0;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _auditErrorMessage =
            e.response?.data?['message']?.toString() ??
            'Falha ao carregar registros de auditoria (${e.message}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _auditErrorMessage = 'Erro inesperado: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingAuditLogs = false);
      }
    }
  }

  Color _severityColor(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'ERROR':
        return const Color(0xFFEF4444);
      case 'WARN':
        return const Color(0xFFF59E0B);
      case 'DEBUG':
      case 'TRACE':
        return const Color(0xFF94A3B8);
      case 'INFO':
      default:
        return const Color(0xFF38BDF8);
    }
  }

  Color _channelColor(String? channel) {
    switch (channel) {
      case 'errors':
        return const Color(0xFFEF4444);
      case 'security-audit':
        return const Color(0xFF8B5CF6);
      case 'application':
        return AdminGeralTheme.bluePrimary;
      default:
        return const Color(0xFF64748B);
    }
  }

  String _channelTitle(String channel) {
    switch (channel) {
      case 'ALL':
        return 'Todos os Canais';
      case 'application':
        return 'Aplicação Geral';
      case 'errors':
        return 'Erros & Alertas';
      case 'security-audit':
        return 'Segurança & Auditoria';
      default:
        return channel;
    }
  }

  Color _categoryColor(String? category) {
    switch (category?.toUpperCase()) {
      case 'AUTH':
        return AdminGeralTheme.purplePrimary;
      case 'SECURITY':
        return AdminGeralTheme.goldBronze;
      case 'ADMIN':
        return AdminGeralTheme.indigoMid;
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _shortTimestamp(String ts) {
    if (ts.isEmpty) return '-';
    final tIndex = ts.indexOf('T');
    if (tIndex >= 0 && ts.length >= tIndex + 9) {
      final timePart = ts.substring(tIndex + 1);
      final plusIdx = timePart.indexOf(RegExp(r'[+-Z]'));
      return plusIdx > 0 ? timePart.substring(0, plusIdx) : timePart;
    }
    return ts;
  }

  void _showFileEntryDialog(Map<String, dynamic> entry) {
    final level = entry['level']?.toString() ?? 'INFO';
    final timestamp = entry['timestamp']?.toString() ?? '-';
    final thread = entry['thread']?.toString() ?? '-';
    final corr = entry['correlationId']?.toString() ?? 'NO_CORR_ID';
    final logger = entry['logger']?.toString() ?? '-';
    final message = entry['message']?.toString() ?? '-';
    final rawLine = entry['rawLine']?.toString() ?? message;
    final lineNumber = entry['lineNumber']?.toString() ?? '-';
    final color = _severityColor(level);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$_selectedFileName · Linha #$lineNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _terminalMetaRow('Timestamp', timestamp),
                  _terminalMetaRow('Thread', thread),
                  _terminalMetaRow('Correlation ID', corr),
                  _terminalMetaRow('Logger', logger),
                  const SizedBox(height: 12),
                  const Text(
                    'Payload & Stacktrace Completo:',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: SelectableText(
                      message,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFFE2E8F0),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: rawLine));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Linha copiada!')),
                );
              },
              icon: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: Color(0xFF38BDF8),
              ),
              label: const Text(
                'Copiar Linha',
                style: TextStyle(color: Color(0xFF38BDF8)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Fechar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _terminalMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAuditDetailsDialog(Map<String, dynamic> log) {
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
          _buildHeroBanner(),
          const SizedBox(height: 16),
          _buildModeSwitcher(),
          const SizedBox(height: 18),
          if (_activeTab == 0)
            _buildServerFilesSection(isDesktop)
          else
            _buildStructuredAuditSection(isDesktop),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      padding: responsiveBannerPadding(context),
      decoration: AdminGeralTheme.heroDecoration(
        context: context,
        borderRadius: 22,
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.terminal_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Central de Logs & Auditoria',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arquivos rotacionados no backend com retenção de $_retentionDays dias e auditoria estruturada.',
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_delete_rounded,
                      color: Color(0xFF6EE7B7),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Retenção: $_retentionDays dias',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _activeTab == 0 ? _loadLogFiles : _loadAuditLogs,
                tooltip: 'Atualizar Logs',
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms);
  }

  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: AdminGeralTheme.surfaceCardDecoration(
        context,
        borderRadius: 16,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _tabPill(
            index: 0,
            icon: Icons.folder_copy_rounded,
            label: 'Arquivos do Servidor (30 dias)',
            badge: '$_totalLogFiles',
          ),
          _tabPill(
            index: 1,
            icon: Icons.history_edu_rounded,
            label: 'Auditoria Estruturada',
            badge: _auditLogsLoadedOnce ? '$_auditTotalElements' : null,
          ),
        ],
      ),
    );
  }

  Widget _tabPill({
    required int index,
    required IconData icon,
    required String label,
    String? badge,
  }) {
    final selected = _activeTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => _activeTab = index);
        if (index == 1 && !_auditLogsLoadedOnce) {
          _loadAuditLogs();
        }
      },
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AdminGeralTheme.actionGradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF334155),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : AdminGeralTheme.indigoMid.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AdminGeralTheme.indigoMid,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerFilesSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTelemetryCards(),
        const SizedBox(height: 16),
        _buildFilesCatalogCard(),
        const SizedBox(height: 16),
        if (_filesErrorMessage != null)
          _buildErrorBanner(_filesErrorMessage!),
        _buildModernTerminalCard(isDesktop),
      ],
    );
  }

  Widget _buildTelemetryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 700;
        final fourCols = constraints.maxWidth >= 1060;
        final cardWidth = fourCols
            ? (constraints.maxWidth - 36) / 4
            : twoCols
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpiTile(
              width: cardWidth,
              icon: Icons.calendar_month_rounded,
              accent: const Color(0xFF10B981),
              title: 'Política de Retenção',
              value: '$_retentionDays dias (1 mês)',
              subtitle: 'Rotação diária + expurgo automático',
            ),
            _kpiTile(
              width: cardWidth,
              icon: Icons.layers_rounded,
              accent: AdminGeralTheme.bluePrimary,
              title: 'Arquivos Separados',
              value: '$_totalLogFiles arquivo(s)',
              subtitle: 'Aplicação · Erros · Segurança',
            ),
            _kpiTile(
              width: cardWidth,
              icon: Icons.storage_rounded,
              accent: AdminGeralTheme.purplePrimary,
              title: 'Armazenamento Total',
              value: _formatBytes(_totalLogBytes),
              subtitle: _logDirectory.isEmpty ? 'Backend logs/' : _logDirectory,
            ),
            _kpiTile(
              width: cardWidth,
              icon: Icons.warning_amber_rounded,
              accent: _fileErrorCount > 0
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFF59E0B),
              title: 'Alertas no Arquivo',
              value: '$_fileErrorCount ERR · $_fileWarnCount WARN',
              subtitle: '$_fileInfoCount eventos INFO registrados',
            ),
          ],
        );
      },
    );
  }

  Widget _kpiTile({
    required double width,
    required IconData icon,
    required Color accent,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AdminGeralTheme.surfaceCardDecoration(
          context,
          borderRadius: 16,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
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

  Widget _buildFilesCatalogCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdminGeralTheme.surfaceCardDecoration(
        context,
        borderRadius: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _channels.map((channel) {
                  final active = _selectedChannel == channel;
                  final color = _channelColor(
                    channel == 'ALL' ? null : channel,
                  );
                  return ChoiceChip(
                    label: Text(_channelTitle(channel)),
                    selected: active,
                    selectedColor: color.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? color : const Color(0xFF475569),
                    ),
                    side: BorderSide(
                      color: active ? color : const Color(0xFFCBD5E1),
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedChannel = channel;
                        _filePage = 0;
                      });
                      _loadLogFiles(keepSelection: false);
                    },
                  );
                }).toList(),
              ),
              OutlinedButton.icon(
                onPressed: _isCleaningUp ? null : _triggerRetentionCleanup,
                icon: _isCleaningUp
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cleaning_services_rounded, size: 16),
                label: Text('Limpar > ${_retentionDays}d'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_logFiles.isEmpty && !_isLoadingFiles)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Nenhum arquivo de log encontrado neste canal.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _logFiles.map((file) {
                  final name = file['fileName']?.toString() ?? '-';
                  final channel = file['channel']?.toString() ?? 'other';
                  final label = file['label']?.toString() ?? channel;
                  final date = file['date']?.toString() ?? '';
                  final compressed = file['compressed'] == true;
                  final size = (file['sizeBytes'] as num?)?.toInt() ?? 0;
                  final isSelected = name == _selectedFileName;
                  final accent = _channelColor(channel);

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _selectedFileName = name;
                          _filePage = 0;
                        });
                        _loadSelectedFileContent();
                      },
                      child: AnimatedContainer(
                        duration: 180.ms,
                        width: 245,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? accent
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.8 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (compressed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'GZ',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$date · ${_formatBytes(size)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _downloadLogFile(name),
                                  child: Icon(
                                    Icons.download_rounded,
                                    size: 16,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernTerminalCard(bool isDesktop) {
    final activeFile = _selectedFileName;
    final totalPages = _fileMatchedLines == 0
        ? 1
        : ((_fileMatchedLines + _fileLimit - 1) ~/ _fileLimit);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Terminal Header & Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          activeFile ?? 'Nenhum arquivo selecionado',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$_fileMatchedLines / $_fileTotalLines evento(s)',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (activeFile != null)
                      TextButton.icon(
                        onPressed: () => _downloadLogFile(activeFile),
                        icon: const Icon(
                          Icons.download_rounded,
                          size: 16,
                          color: Color(0xFF38BDF8),
                        ),
                        label: const Text(
                          'Baixar Arquivo',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isDesktop ? 310 : double.infinity,
                      height: 38,
                      child: TextField(
                        controller: _fileSearchController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF020617),
                          hintText:
                              'Buscar por mensagem, logger ou correlationId...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                        onSubmitted: (_) {
                          setState(() => _filePage = 0);
                          _loadSelectedFileContent();
                        },
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      children: _severities.map((sev) {
                        final selected = _fileSeverityFilter == sev;
                        final color = sev == 'ALL'
                            ? const Color(0xFF94A3B8)
                            : _severityColor(sev);
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              _fileSeverityFilter = sev;
                              _filePage = 0;
                            });
                            _loadSelectedFileContent();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withValues(alpha: 0.22)
                                  : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? color
                                    : const Color(0xFF334155),
                              ),
                            ),
                            child: Text(
                              sev == 'ALL' ? 'TODOS' : sev,
                              style: TextStyle(
                                color: selected
                                    ? color
                                    : const Color(0xFFCBD5E1),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _filePage = 0);
                        _loadSelectedFileContent();
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Aplicar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminGeralTheme.bluePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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

          // Terminal Content
          if (_isLoadingFileContent || (_isLoadingFiles && _logFiles.isEmpty))
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              ),
            )
          else if (_fileEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42, horizontal: 20),
              child: Center(
                child: Text(
                  'Nenhuma entrada corresponde aos filtros aplicados neste arquivo.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _fileEntries.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: Color(0xFF1E293B),
              ),
              itemBuilder: (context, index) {
                final entry = _fileEntries[index];
                final level = entry['level']?.toString() ?? 'INFO';
                final timestamp = entry['timestamp']?.toString() ?? '';
                final corr = entry['correlationId']?.toString() ?? 'NO_CORR_ID';
                final logger = entry['logger']?.toString() ?? '-';
                final message = entry['message']?.toString() ?? '';
                final lineNumber = entry['lineNumber']?.toString() ?? '-';
                final levelColor = _severityColor(level);

                return InkWell(
                  onTap: () => _showFileEntryDialog(entry),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '#$lineNumber',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _shortTimestamp(timestamp),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: levelColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: levelColor.withValues(alpha: 0.65),
                                ),
                              ),
                              child: Text(
                                level,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: levelColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            if (corr != 'NO_CORR_ID')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  corr,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFFC4B5FD),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Text(
                              logger,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF38BDF8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFFE2E8F0),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Terminal Pagination Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Página ${_filePage + 1} de $totalPages · Ordem cronológica reversa',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.navigate_before_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _filePage > 0
                          ? () {
                              setState(() => _filePage--);
                              _loadSelectedFileContent();
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.navigate_next_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _filePage + 1 < totalPages
                          ? () {
                              setState(() => _filePage++);
                              _loadSelectedFileContent();
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStructuredAuditSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: AdminGeralTheme.surfaceCardDecoration(
            context,
            borderRadius: 16,
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
                    SizedBox(
                      width: isDesktop ? 260 : double.infinity,
                      height: 42,
                      child: TextField(
                        controller: _auditSearchController,
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
                          setState(() => _auditPage = 0);
                          _loadAuditLogs();
                        },
                      ),
                    ),
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
                            _auditPage = 0;
                          });
                          _loadAuditLogs();
                        }
                      },
                    ),
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
                            _auditPage = 0;
                          });
                          _loadAuditLogs();
                        }
                      },
                    ),
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
                            _auditPage = 0;
                          });
                          _loadAuditLogs();
                        }
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _auditPage = 0);
                        _loadAuditLogs();
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
        if (_auditErrorMessage != null) _buildErrorBanner(_auditErrorMessage!),
        if (_isLoadingAuditLogs)
          const Padding(
            padding: EdgeInsets.all(24),
            child: AppLoader(
              message: 'Carregando logs de auditoria...',
              accentColor: AdminGeralTheme.indigoMid,
            ),
          )
        else if (_auditLogs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const AppEmptyIllustration(
                    icon: Icons.security_rounded,
                    size: 76,
                    accentColor: AdminGeralTheme.indigoMid,
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
                itemCount: _auditLogs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = _auditLogs[index];
                  final severity = log['severity']?.toString() ?? 'INFO';
                  final category = log['category']?.toString() ?? 'SYSTEM';
                  final action = log['action']?.toString() ?? '-';
                  final actorEmail = log['actorEmail']?.toString() ?? '-';
                  final timestamp =
                      log['timestamp']?.toString().replaceFirst('T', ' ') ??
                      '-';
                  final result = log['result']?.toString() ?? 'SUCCESS';

                  return ListTile(
                    onTap: () => _showAuditDetailsDialog(log),
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
                        color: _severityColor(severity).withValues(alpha: 0.12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: $_auditTotalElements registros (Página ${_auditPage + 1} de $_auditTotalPages)',
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
                    onPressed: _auditPage > 0
                        ? () {
                            setState(() => _auditPage--);
                            _loadAuditLogs();
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_next_rounded),
                    onPressed: _auditPage + 1 < _auditTotalPages
                        ? () {
                            setState(() => _auditPage++);
                            _loadAuditLogs();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF87171)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
