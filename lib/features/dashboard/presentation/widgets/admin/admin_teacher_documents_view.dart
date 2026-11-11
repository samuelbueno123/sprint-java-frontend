import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/network/api_client.dart';
import '../responsive_layout.dart';

class AdminTeacherDocumentsView extends StatefulWidget {
  const AdminTeacherDocumentsView({super.key});

  @override
  State<AdminTeacherDocumentsView> createState() =>
      _AdminTeacherDocumentsViewState();
}

class _AdminTeacherDocumentsViewState extends State<AdminTeacherDocumentsView> {
  final Dio _dio = ApiClient().dio;

  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _documents = [];
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalElements = 0;
  final int _pageSize = 15;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = <String, dynamic>{
        'page': _currentPage,
        'size': _pageSize,
      };

      final q = _searchController.text.trim();
      if (q.isNotEmpty) {
        queryParams['query'] = q;
      }

      final response = await _dio.get(
        '/api/admin/documents',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final content = data['content'] as List<dynamic>? ?? [];
        setState(() {
          _documents = content
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _currentPage = data['page'] ?? 0;
          _totalPages = max(1, (data['totalPages'] as num?)?.toInt() ?? 1);
          _totalElements = (data['totalElements'] as num?)?.toInt() ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _documents = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha ao carregar documentos docentes: $e';
        _isLoading = false;
      });
    }
  }

  String _formatBytes(num? bytes) {
    if (bytes == null || bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (log(bytes) / log(1024)).floor();
    i = i.clamp(0, suffixes.length - 1);
    final numVal = bytes / pow(1024, i);
    return '${numVal.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }

  IconData _getFileIcon(String? contentType, String? fileName) {
    final mime = (contentType ?? '').toLowerCase();
    final ext = (fileName ?? '').toLowerCase();
    if (mime.contains('pdf') || ext.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    }
    if (mime.contains('image') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.jpeg')) {
      return Icons.image_rounded;
    }
    if (mime.contains('word') ||
        ext.endsWith('.doc') ||
        ext.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String? contentType, String? fileName) {
    final mime = (contentType ?? '').toLowerCase();
    final ext = (fileName ?? '').toLowerCase();
    if (mime.contains('pdf') || ext.endsWith('.pdf')) {
      return const Color(0xFFE11D48);
    }
    if (mime.contains('image') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.jpeg')) {
      return const Color(0xFF0284C7);
    }
    return const Color(0xFF4F46E5);
  }

  void _showDocumentDetails(Map<String, dynamic> doc) {
    final id = doc['id'];
    final fileName = doc['fileName'] ?? 'documento';
    final teacherName = doc['teacherName'] ?? 'Docente';
    final teacherEmail = doc['teacherEmail'] ?? '-';
    final institution = doc['institutionName'] ?? 'Não informada';
    final contentType = doc['contentType'] ?? 'application/octet-stream';
    final sizeFormatted = _formatBytes(doc['fileSize'] as num?);
    final created = _formatDateTime(doc['createdAt']?.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getFileIcon(contentType, fileName),
              color: _getFileColor(contentType, fileName),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Detalhes da Comprovação Docente',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Arquivo:', fileName),
              const SizedBox(height: 8),
              _buildDetailRow('Docente:', teacherName),
              const SizedBox(height: 8),
              _buildDetailRow('E-mail:', teacherEmail),
              const SizedBox(height: 8),
              _buildDetailRow('Instituição:', institution),
              const SizedBox(height: 8),
              _buildDetailRow('Tamanho:', sizeFormatted),
              const SizedBox(height: 8),
              _buildDetailRow('Tipo MIME:', contentType),
              const SizedBox(height: 8),
              _buildDetailRow('Enviado em:', created),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
            ),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Baixar Arquivo'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _downloadDocument(id, fileName);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDocument(dynamic id, String fileName) async {
    try {
      final downloadUrl = '/api/admin/documents/$id/download';
      // In web or desktop, we can request the byte payload via dio
      final resp = await _dio.get<List<int>>(
        downloadUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Arquivo "$fileName" (${_formatBytes(resp.data?.length)}) baixado com sucesso pelo endpoint administrativo!',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao baixar arquivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final distinctTeachers = _documents
        .map((d) => d['teacherId'])
        .where((id) => id != null)
        .toSet()
        .length;
    final totalBytes = _documents.fold<num>(
      0,
      (acc, d) => acc + ((d['fileSize'] as num?) ?? 0),
    );

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
                  Color(0xFF3730A3),
                  Color(0xFF4F46E5),
                  Color(0xFF6366F1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.folder_shared_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Documentos & Diplomas Docentes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Auditoria, inspeção técnica e download de comprovações de professores da plataforma.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Atualizar Documentos',
                  onPressed: _loadDocuments,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 20),

          // Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Total de Comprovações',
                  value: '$_totalElements',
                  icon: Icons.file_copy_rounded,
                  color: const Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Docentes Verificados',
                  value: '$distinctTeachers',
                  icon: Icons.person_search_rounded,
                  color: const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Volume na Página',
                  value: _formatBytes(totalBytes),
                  icon: Icons.storage_rounded,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Search Bar
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText:
                            'Buscar por nome do docente, e-mail ou nome do arquivo...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadDocuments();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) {
                        _currentPage = 0;
                        _loadDocuments();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    onPressed: () {
                      _currentPage = 0;
                      _loadDocuments();
                    },
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Buscar'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFB42318),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadDocuments,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_documents.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Nenhum documento encontrado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Não foram localizados certificados ou diplomas com os critérios selecionados.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _documents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final doc = _documents[index];
                final fileName = doc['fileName']?.toString() ?? 'arquivo';
                final teacherName = doc['teacherName']?.toString() ?? 'Docente';
                final teacherEmail = doc['teacherEmail']?.toString() ?? '';
                final institution =
                    doc['institutionName']?.toString() ?? 'Sem instituição';
                final contentType = doc['contentType']?.toString();
                final sizeFormatted = _formatBytes(doc['fileSize'] as num?);
                final created = _formatDateTime(doc['createdAt']?.toString());
                final icon = _getFileIcon(contentType, fileName);
                final color = _getFileColor(contentType, fileName);

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    fileName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      sizeFormatted,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Docente: $teacherName ($teacherEmail) • $institution',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Enviado em $created • ID #${doc['id']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: color),
                            foregroundColor: color,
                          ),
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                          ),
                          label: const Text('Inspecionar'),
                          onPressed: () => _showDocumentDetails(doc),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Baixar Comprovação',
                          icon: Icon(Icons.download_rounded, color: color),
                          onPressed: () =>
                              _downloadDocument(doc['id'], fileName),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 16),

          // Pagination
          if (_totalPages > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 0
                      ? () {
                          setState(() {
                            _currentPage--;
                          });
                          _loadDocuments();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  'Página ${_currentPage + 1} de $_totalPages',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  onPressed: _currentPage < _totalPages - 1
                      ? () {
                          setState(() {
                            _currentPage++;
                          });
                          _loadDocuments();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
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
}
