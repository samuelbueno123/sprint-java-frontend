import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

/// Native/desktop image picker with automatic proportional resizing to <= 1024px
/// and PNG data-URL normalization so backend validation always succeeds.
Future<String?> pickLocalImage() async {
  final files = await FilePicker.pickFiles(type: FileType.image);
  if (files.isEmpty) return null;

  final picked = files.first;
  var bytes = await picked.readAsBytes();
  if (bytes.isEmpty && picked.path != null) {
    bytes = await File(picked.path!).readAsBytes();
  }
  if (bytes.isEmpty) {
    throw const FormatException('O arquivo de imagem selecionado está vazio.');
  }
  if (bytes.length > 15 * 1024 * 1024) {
    throw const FormatException('A imagem escolhida excede o limite de 15 MB.');
  }

  final probeCodec = await ui.instantiateImageCodec(bytes);
  final probeFrame = await probeCodec.getNextFrame();
  final origW = probeFrame.image.width;
  final origH = probeFrame.image.height;
  probeFrame.image.dispose();
  probeCodec.dispose();

  if (origW <= 0 || origH <= 0) {
    throw const FormatException('Não foi possível decodificar esta imagem.');
  }

  int targetDim = 960;
  for (final attemptMax in <int>[targetDim, 640, 420]) {
    final scale = (origW <= attemptMax && origH <= attemptMax)
        ? 1.0
        : math.min(attemptMax / origW, attemptMax / origH);
    final w = math.max(1, (origW * scale).round());
    final h = math.max(1, (origH * scale).round());

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: w,
      targetHeight: h,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    frame.image.dispose();
    codec.dispose();

    if (byteData == null) continue;
    final pngBytes = byteData.buffer.asUint8List();
    if (pngBytes.length <= 1_400_000 || attemptMax == 420) {
      return 'data:image/png;base64,${base64Encode(pngBytes)}';
    }
  }

  throw const FormatException(
    'Não foi possível otimizar a imagem selecionada. Tente outro arquivo.',
  );
}
