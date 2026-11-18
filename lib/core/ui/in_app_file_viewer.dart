import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/file_download_helper.dart';
import '../utils/in_app_pdf_view.dart';

enum InAppFileKind { image, pdf, text, binary }

/// Visualizador interno universal de arquivos (imagens com zoom, PDF embutido na Web,
/// arquivos texto/logs/JSON/CSV pesquisáveis e inspetor binário com download seguro).
class InAppFileViewerDialog extends StatefulWidget {
  const InAppFileViewerDialog({
    super.key,
    required this.fileName,
    this.initialBytes,
    this.contentType,
    this.subtitle,
    this.dio,
    this.downloadUrl,
  });

  final String fileName;
  final Uint8List? initialBytes;
  final String? contentType;
  final String? subtitle;
  final Dio? dio;
  final String? downloadUrl;

  static Future<void> showBytes(
    BuildContext context, {
    required String fileName,
    required Uint8List bytes,
    String? contentType,
    String? subtitle,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => InAppFileViewerDialog(
        fileName: fileName,
        initialBytes: bytes,
        contentType: contentType,
        subtitle: subtitle,
      ),
    );
  }

  static Future<void> openFromUrl(
    BuildContext context, {
    required Dio dio,
    required String url,
    required String fileName,
    String? contentType,
    String? subtitle,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => InAppFileViewerDialog(
        fileName: fileName,
        contentType: contentType,
        subtitle: subtitle,
        dio: dio,
        downloadUrl: url,
      ),
    );
  }

  static InAppFileKind detectFileKind({
    required String fileName,
    String? contentType,
    Uint8List? bytes,
  }) {
    final mime = (contentType ?? '').toLowerCase();
    final name = fileName.toLowerCase();

    if (mime.contains('pdf') ||
        name.endsWith('.pdf') ||
        (bytes != null &&
            bytes.length >= 5 &&
            bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46)) {
      return InAppFileKind.pdf;
    }

    if (mime.startsWith('image/') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif') ||
        name.endsWith('.bmp')) {
      return InAppFileKind.image;
    }

    if (mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('xml') ||
        mime.contains('csv') ||
        name.endsWith('.txt') ||
        name.endsWith('.log') ||
        name.endsWith('.json') ||
        name.endsWith('.csv') ||
        name.endsWith('.xml') ||
        name.endsWith('.md') ||
        name.endsWith('.yaml') ||
        name.endsWith('.yml') ||
        name.endsWith('.sql')) {
      return InAppFileKind.text;
    }

    if (bytes != null && bytes.isNotEmpty && bytes.length <= 2 * 1024 * 1024) {
      final hasNull = bytes.take(min(bytes.length, 4096)).contains(0);
      if (!hasNull) {
        return InAppFileKind.text;
      }
    }

    return InAppFileKind.binary;
  }

  @override
  State<InAppFileViewerDialog> createState() => _InAppFileViewerDialogState();
}

class _InAppFileViewerDialogState extends State<InAppFileViewerDialog> {
  final TransformationController _imageController = TransformationController();
  final TextEditingController _textSearchController = TextEditingController();

  Uint8List? _bytes;
  bool _loading = false;
  String? _error;
  bool _expanded = false;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes;
    if (_bytes == null && widget.dio != null && widget.downloadUrl != null) {
      _fetchRemoteBytes();
    }
  }

  @override
  void dispose() {
    _imageController.dispose();
    _textSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRemoteBytes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.dio!.get<List<int>>(
        widget.downloadUrl!,
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(response.data ?? const <int>[]);
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['message']?.toString() ??
            'Falha ao carregar arquivo (${e.message}).';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro inesperado ao abrir arquivo: $e';
        _loading = false;
      });
    }
  }

  Future<void> _downloadCurrentFile() async {
    final data = _bytes;
    if (data == null) return;
    final downloaded = await triggerBytesDownload(
      bytes: data,
      fileName: widget.fileName,
      mimeType: widget.contentType ?? 'application/octet-stream',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          downloaded
              ? 'Download de "${widget.fileName}" iniciado.'
              : 'Arquivo "${widget.fileName}" (${_formatBytes(data.length)}) pronto.',
        ),
      ),
    );
  }

  void _setZoom(double next) {
    final clamped = next.clamp(0.5, 4.0);
    setState(() {
      _zoom = clamped;
      _imageController.value = Matrix4.identity()..scaleByDouble(clamped, clamped, 1.0, 1.0);
    });
  }

  String _formatBytes(int len) {
    if (len <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var idx = (log(len) / log(1024)).floor().clamp(0, units.length - 1);
    return '${(len / pow(1024, idx)).toStringAsFixed(1)} ${units[idx]}';
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final dialogW = _expanded
        ? screen.width * 0.96
        : min(960.0, screen.width * 0.92);
    final dialogH = _expanded
        ? screen.height * 0.92
        : min(700.0, screen.height * 0.84);

    final bytes = _bytes;
    final kind = InAppFileViewerDialog.detectFileKind(
      fileName: widget.fileName,
      contentType: widget.contentType,
      bytes: bytes,
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogW,
        height: dialogH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(_iconForKind(kind), color: const Color(0xFF38BDF8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        if (widget.subtitle != null || bytes != null)
                          Text(
                            [
                              if (widget.subtitle != null) widget.subtitle!,
                              if (bytes != null) _formatBytes(bytes.length),
                              _labelForKind(kind),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (bytes != null)
                    TextButton.icon(
                      onPressed: _downloadCurrentFile,
                      icon: const Icon(
                        Icons.download_rounded,
                        size: 16,
                        color: Color(0xFF38BDF8),
                      ),
                      label: const Text(
                        'Baixar',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: _expanded ? 'Restaurar tamanho' : 'Tela cheia',
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar visualizador',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _buildBody(context, bytes, kind),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Uint8List? bytes,
    InAppFileKind kind,
  ) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Abrindo arquivo dentro da plataforma...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 44,
            ),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
            if (widget.downloadUrl != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _fetchRemoteBytes,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      );
    }
    if (bytes == null) {
      return const Center(child: Text('Nenhum conteúdo carregado.'));
    }

    switch (kind) {
      case InAppFileKind.image:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Diminuir zoom',
                  onPressed: () => _setZoom(_zoom - 0.25),
                  icon: const Icon(Icons.zoom_out_rounded),
                ),
                Text(
                  '${(_zoom * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  tooltip: 'Aumentar zoom',
                  onPressed: () => _setZoom(_zoom + 0.25),
                  icon: const Icon(Icons.zoom_in_rounded),
                ),
                TextButton(
                  onPressed: () => _setZoom(1.0),
                  child: const Text('Resetar'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1120),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InteractiveViewer(
                  transformationController: _imageController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Não foi possível decodificar esta imagem.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

      case InAppFileKind.pdf:
        return InAppPdfView(
          bytes: bytes,
          fileName: widget.fileName,
          onDownload: _downloadCurrentFile,
        );

      case InAppFileKind.text:
        final decoded = utf8.decode(bytes, allowMalformed: true);
        final allLines = decoded.split('\n');
        final query = _textSearchController.text.trim().toLowerCase();
        final visibleLines = query.isEmpty
            ? allLines
            : allLines
                  .where((line) => line.toLowerCase().contains(query))
                  .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  height: 38,
                  child: TextField(
                    controller: _textSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar no conteúdo...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${visibleLines.length} linha(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: decoded));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Conteúdo copiado para a área de transferência.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('Copiar'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1120),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    visibleLines.isEmpty
                        ? 'Nenhuma linha encontrada para "$query".'
                        : visibleLines.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      color: Color(0xFFE2E8F0),
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

      case InAppFileKind.binary:
        final hexHead = bytes
            .take(16)
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.insert_drive_file_rounded,
                  size: 48,
                  color: Color(0xFF4F46E5),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tipo: ${widget.contentType ?? "binário"} · Assinatura: $hexHead',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _downloadCurrentFile,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Baixar Arquivo'),
                ),
              ],
            ),
          ),
        );
    }
  }

  IconData _iconForKind(InAppFileKind kind) {
    return switch (kind) {
      InAppFileKind.image => Icons.image_rounded,
      InAppFileKind.pdf => Icons.picture_as_pdf_rounded,
      InAppFileKind.text => Icons.article_rounded,
      InAppFileKind.binary => Icons.insert_drive_file_rounded,
    };
  }

  String _labelForKind(InAppFileKind kind) {
    return switch (kind) {
      InAppFileKind.image => 'Imagem',
      InAppFileKind.pdf => 'PDF',
      InAppFileKind.text => 'Texto',
      InAppFileKind.binary => 'Binário',
    };
  }
}
