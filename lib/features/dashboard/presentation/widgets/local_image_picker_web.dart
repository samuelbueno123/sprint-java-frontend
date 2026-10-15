import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' as ui;

import 'package:web/web.dart' as web;

Future<String?> pickLocalImage() async {
  final completer = Completer<String?>();
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
    final isJpg =
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        file.type == 'image/jpeg';
    final isPng = name.endsWith('.png') || file.type == 'image/png';
    if (!isJpg && !isPng) {
      completer.completeError(
        'Formato inválido. Apenas arquivos JPG e PNG são permitidos.',
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
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final width = image.width;
        final height = image.height;
        image.dispose();
        codec.dispose();
        if (width > 1024 || height > 1024) {
          completer.completeError(
            'A dimensão máxima permitida é 1024x1024 pixels. (Imagem: ${width}x$height).',
          );
          return;
        }
        final mime = isPng ? 'image/png' : 'image/jpeg';
        completer.complete('data:$mime;base64,${base64Encode(bytes)}');
      } catch (error) {
        if (!completer.isCompleted) {
          completer.completeError(
            'Não foi possível decodificar a imagem selecionada: $error',
          );
        }
      }
    });
  });
  input.click();
  return completer.future;
}
