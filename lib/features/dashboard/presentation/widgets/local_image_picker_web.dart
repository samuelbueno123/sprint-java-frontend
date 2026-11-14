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

  StreamSubscription<web.Event>? changeSub;
  StreamSubscription<web.Event>? cancelSub;
  StreamSubscription<web.Event>? focusSub;
  StreamSubscription<web.Event>? loadEndSub;
  Timer? focusFallbackTimer;

  void cleanup() {
    focusFallbackTimer?.cancel();
    changeSub?.cancel();
    cancelSub?.cancel();
    focusSub?.cancel();
    loadEndSub?.cancel();
  }

  void completeValue(String? value) {
    cleanup();
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  void completeError(Object error) {
    cleanup();
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  cancelSub = const web.EventStreamProvider<web.Event>(
    'cancel',
  ).forTarget(input).listen((_) => completeValue(null));

  focusSub = const web.EventStreamProvider<web.Event>('focus')
      .forTarget(web.window)
      .listen((_) {
        focusFallbackTimer?.cancel();
        focusFallbackTimer = Timer(const Duration(milliseconds: 500), () {
          final files = input.files;
          if (!completer.isCompleted && (files == null || files.length == 0)) {
            completeValue(null);
          }
        });
      });

  changeSub = input.onChange.listen((_) {
    focusFallbackTimer?.cancel();
    final files = input.files;
    if (files == null || files.length == 0) {
      completeValue(null);
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
      completeError(
        'Formato inválido. Apenas arquivos JPG e PNG são permitidos.',
      );
      return;
    }

    final reader = web.FileReader();
    reader.readAsArrayBuffer(file);
    loadEndSub = reader.onLoadEnd.listen((_) async {
      final result = reader.result;
      if (result == null) {
        completeError('Falha ao ler o arquivo selecionado.');
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
          completeError(
            'A dimensão máxima permitida é 1024x1024 pixels. (Imagem: ${width}x$height).',
          );
          return;
        }
        final mime = isPng ? 'image/png' : 'image/jpeg';
        completeValue('data:$mime;base64,${base64Encode(bytes)}');
      } catch (error) {
        completeError(
          'Não foi possível decodificar a imagem selecionada: $error',
        );
      }
    });
  });
  input.click();
  return completer.future;
}
