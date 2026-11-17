import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Picks a local image file in Flutter Web, automatically downscaling large
/// images via HTML5 Canvas to <= 1024x1024 so high-res camera/phone photos
/// save reliably without exceeding payload limits.
Future<String?> pickLocalImage() async {
  final completer = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/png,image/jpeg,image/webp,image/gif,image/bmp,image/*'
    ..style.display = 'none';

  web.document.body?.append(input);

  void cleanup() {
    try {
      input.remove();
    } catch (_) {}
  }

  void completeError(Object err) {
    if (!completer.isCompleted) {
      cleanup();
      completer.completeError(err);
    }
  }

  void completeValue(String? val) {
    if (!completer.isCompleted) {
      cleanup();
      completer.complete(val);
    }
  }

  void onFocusBack(web.Event _) {
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!completer.isCompleted && (input.files == null || input.files!.length == 0)) {
        completeValue(null);
      }
    });
  }

  web.window.addEventListener('focus', onFocusBack.toJS);

  input.onChange.listen((_) async {
    try {
      final files = input.files;
      if (files == null || files.length == 0) {
        completeValue(null);
        return;
      }
      final file = files.item(0);
      if (file == null) {
        completeValue(null);
        return;
      }
      if (file.size > 15 * 1024 * 1024) {
        completeError(
          const FormatException(
            'A imagem selecionada é muito grande (máximo 15 MB).',
          ),
        );
        return;
      }

      final reader = web.FileReader();
      reader.onerror = ((web.Event _) {
        completeError(
          const FormatException(
            'Não foi possível ler o arquivo selecionado do seu dispositivo.',
          ),
        );
      }).toJS;
      reader.onLoadEnd.listen((_) async {
        try {
          final result = reader.result;
          if (result == null) {
            completeError(
              const FormatException('O arquivo selecionado está vazio.'),
            );
            return;
          }
          final rawDataUrl = (result as JSString).toDart;
          if (!rawDataUrl.startsWith('data:image/')) {
            completeError(
              const FormatException(
                'Formato inválido. Escolha uma imagem PNG, JPG, GIF ou WebP.',
              ),
            );
            return;
          }

          final normalized = await _resizeWithCanvasIfNeeded(
            rawDataUrl,
            mimeType: file.type,
          );
          completeValue(normalized);
        } catch (err) {
          completeError(
            err is FormatException
                ? err
                : FormatException(
                    'Não foi possível processar a imagem escolhida ($err).',
                  ),
          );
        }
      });
      reader.readAsDataURL(file);
    } catch (err) {
      completeError(
        FormatException('Falha ao abrir seletor de imagem: $err'),
      );
    }
  });

  input.click();
  return completer.future.whenComplete(() {
    try {
      web.window.removeEventListener('focus', onFocusBack.toJS);
    } catch (_) {}
  });
}

Future<String> _resizeWithCanvasIfNeeded(
  String rawDataUrl, {
  String mimeType = '',
}) async {
  final imgCompleter = Completer<web.HTMLImageElement>();
  final img = web.HTMLImageElement();
  img.onLoad.listen((_) {
    if (!imgCompleter.isCompleted) imgCompleter.complete(img);
  });
  img.onError.listen((_) {
    if (!imgCompleter.isCompleted) {
      imgCompleter.completeError(
        const FormatException(
          'Arquivo de imagem corrompido ou formato não suportado pelo navegador.',
        ),
      );
    }
  });
  img.src = rawDataUrl;

  final loaded = await imgCompleter.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw const FormatException(
      'Tempo limite ao decodificar a imagem selecionada.',
    ),
  );

  final origW = loaded.naturalWidth;
  final origH = loaded.naturalHeight;
  if (origW <= 0 || origH <= 0) {
    throw const FormatException('Dimensões de imagem inválidas.');
  }

  const maxDim = 960;
  final ratio = (origW <= maxDim && origH <= maxDim)
      ? 1.0
      : (maxDim / origW < maxDim / origH ? maxDim / origW : maxDim / origH);
  final targetW = (origW * ratio).round().clamp(1, maxDim);
  final targetH = (origH * ratio).round().clamp(1, maxDim);

  // Use JPEG for opaque/large photos and PNG for small/transparent images.
  final canvas = web.HTMLCanvasElement()
    ..width = targetW
    ..height = targetH;
  final ctx = canvas.context2D;
  ctx.drawImage(loaded, 0, 0, targetW.toDouble(), targetH.toDouble());

  final preferPng = mimeType.toLowerCase().contains('png') ||
      mimeType.toLowerCase().contains('webp') ||
      mimeType.toLowerCase().contains('gif');

  String output = preferPng
      ? canvas.toDataURL('image/png')
      : canvas.toDataURL('image/jpeg', 0.88.toJS);

  if (output.length > 1_400_000) {
    // Re-encode with JPEG compression on white background so payload stays compact.
    final fallbackCanvas = web.HTMLCanvasElement()
      ..width = (targetW * 0.75).round().clamp(64, 720)
      ..height = (targetH * 0.75).round().clamp(64, 720);
    final fCtx = fallbackCanvas.context2D;
    fCtx.fillStyle = '#FFFFFF'.toJS;
    fCtx.fillRect(0, 0, fallbackCanvas.width.toDouble(), fallbackCanvas.height.toDouble());
    fCtx.drawImage(
      loaded,
      0,
      0,
      fallbackCanvas.width.toDouble(),
      fallbackCanvas.height.toDouble(),
    );
    output = fallbackCanvas.toDataURL('image/jpeg', 0.82.toJS);
  }

  return output;
}
