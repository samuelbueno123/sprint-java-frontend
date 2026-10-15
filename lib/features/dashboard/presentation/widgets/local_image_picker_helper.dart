import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class LocalImagePickerHelper {
  LocalImagePickerHelper._();

  /// Abre a janela nativa do sistema para escolha de um arquivo local de imagem (JPG ou PNG).
  /// Valida estritamente se o formato é JPG ou PNG e se as dimensões são de no máximo 1024x1024 pixels.
  /// Retorna a Data URL (base64) da imagem pronta para envio ao servidor.
  static Future<String?> pickLocalImage() async {
    final completer = Completer<String?>();

    if (kIsWeb) {
      final input = web.document.createElement('input') as web.HTMLInputElement;
      input.type = 'file';
      input.accept = 'image/jpeg,image/png,.jpg,.jpeg,.png';

      input.onChange.listen((_) {
        final files = input.files;
        if (files == null || files.length == 0) {
          completer.complete(null);
          return;
        }

        final file = files.item(0)!;
        final name = file.name.toLowerCase();

        // 1. Validação de Formato (APENAS JPG/PNG)
        final isJpg =
            name.endsWith('.jpg') ||
            name.endsWith('.jpeg') ||
            file.type == 'image/jpeg';
        final isPng = name.endsWith('.png') || file.type == 'image/png';

        if (!isJpg && !isPng) {
          completer.completeError(
            'Formato inválido. Apenas arquivos de imagem JPG e PNG são permitidos.',
          );
          return;
        }

        final reader = web.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((_) async {
          final result = reader.result;
          if (result == null) {
            completer.completeError('Falha ao ler o arquivo selecionado.');
            return;
          }

          try {
            final bytes = (result as JSArrayBuffer).toDart.asUint8List();

            // 2. Validação de Resolução (Máximo 1024x1024)
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            final image = frame.image;

            if (image.width > 1024 || image.height > 1024) {
              completer.completeError(
                'A dimensão máxima permitida é 1024x1024 pixels. (A sua imagem possui ${image.width}x${image.height} pixels).',
              );
              return;
            }

            final mime = isPng ? 'image/png' : 'image/jpeg';
            final base64Data = base64Encode(bytes);
            final dataUrl = 'data:$mime;base64,$base64Data';

            completer.complete(dataUrl);
          } catch (e) {
            completer.completeError(
              'Não foi possível decodificar a imagem selecionada: $e',
            );
          }
        });
      });

      input.click();
    } else {
      completer.completeError('Seleção de arquivo disponível no ambiente web.');
    }

    return completer.future;
  }
}
