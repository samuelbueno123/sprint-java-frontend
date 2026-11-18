import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class InAppPdfView extends StatelessWidget {
  const InAppPdfView({
    super.key,
    required this.bytes,
    required this.fileName,
    this.onDownload,
  });

  final Uint8List bytes;
  final String fileName;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final ascii = latin1.decode(
      bytes.length > 65536 ? bytes.sublist(0, 65536) : bytes,
      allowInvalid: true,
    );
    final headerMatch = RegExp(r'%PDF-(\d\.\d)').firstMatch(ascii);
    final pdfVersion = headerMatch?.group(1) ?? '-';
    final pageMatches = RegExp(r'/Type\s*/Page\b').allMatches(ascii).length;

    return Container(
      width: double.infinity,
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                size: 48,
                color: Color(0xFFE11D48),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'PDF carregado na memória (${bytes.length} bytes · Versão $pdfVersion${pageMatches > 0 ? " · ~$pageMatches página(s)" : ""})',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (onDownload != null)
              FilledButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Baixar PDF'),
              ),
          ],
        ),
      ),
    );
  }
}
