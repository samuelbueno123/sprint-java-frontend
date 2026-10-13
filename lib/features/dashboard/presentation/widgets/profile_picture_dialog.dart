import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Diálogo para alteração da foto de perfil com validação estrita:
/// - Formatos aceitos: APENAS JPG e PNG.
/// - Resolução máxima: 1024x1024 pixels.
class ProfilePictureDialog extends StatefulWidget {
  const ProfilePictureDialog({
    super.key,
    required this.currentPictureUrl,
    required this.onPictureSelected,
  });

  final String? currentPictureUrl;
  final ValueChanged<String> onPictureSelected;

  static void show(
    BuildContext context, {
    required String? currentPictureUrl,
    required ValueChanged<String> onPictureSelected,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => ProfilePictureDialog(
        currentPictureUrl: currentPictureUrl,
        onPictureSelected: onPictureSelected,
      ),
    );
  }

  @override
  State<ProfilePictureDialog> createState() => _ProfilePictureDialogState();
}

class _ProfilePictureDialogState extends State<ProfilePictureDialog> {
  final _urlController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.currentPictureUrl ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _validateAndApply(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Informe a URL da imagem JPG ou PNG.');
      return;
    }

    final lower = url.toLowerCase();
    final isJpgOrPng = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.contains('format=jpg') ||
        lower.contains('format=png') ||
        lower.startsWith('data:image/jpeg') ||
        lower.startsWith('data:image/jpg') ||
        lower.startsWith('data:image/png');

    if (!isJpgOrPng) {
      setState(
        () => _errorMessage =
            'Formato inválido. Apenas imagens em formato JPG e PNG são aceitas.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (url.startsWith('data:image/')) {
        final base64Str = url.split(',').last;
        final bytes = base64Decode(base64Str);
        await _verifyDimensions(bytes);
      } else {
        final provider = NetworkImage(url);
        final stream = provider.resolve(const ImageConfiguration());
        final completer = Completer<ui.Image>();
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (info, _) {
            completer.complete(info.image);
            stream.removeListener(listener);
          },
          onError: (error, _) {
            completer.completeError('Não foi possível carregar a imagem da URL informada.');
            stream.removeListener(listener);
          },
        );
        stream.addListener(listener);
        final image = await completer.future;

        if (image.width > 1024 || image.height > 1024) {
          throw 'A dimensão máxima da imagem é 1024x1024 pixels. (Sua imagem: ${image.width}x${image.height})';
        }
      }

      widget.onPictureSelected(url);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyDimensions(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    if (img.width > 1024 || img.height > 1024) {
      throw 'A dimensão máxima da imagem é 1024x1024 pixels. (Sua imagem: ${img.width}x${img.height})';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.photo_camera_rounded, color: Color(0xFF5869D8)),
          SizedBox(width: 10),
          Text(
            'Alterar Foto de Perfil',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apenas formatos JPG e PNG de até 1024x1024 pixels são aceitos.',
              style: TextStyle(fontSize: 13, color: Color(0xFF73788B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL da imagem (JPG ou PNG)',
                hintText: 'https://exemplo.com/foto.jpg',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF3C6C2)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFB42318), fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading
              ? null
              : () => _validateAndApply(_urlController.text),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF5869D8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Salvar Foto'),
        ),
      ],
    );
  }
}
