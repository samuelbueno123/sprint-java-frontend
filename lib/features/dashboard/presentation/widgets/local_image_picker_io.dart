import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

Future<String?> pickLocalImage() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png'],
  );
  if (files.isEmpty) return null;

  final file = files.single;
  final extension = (file.extension ?? '').toLowerCase();
  if (!const {'jpg', 'jpeg', 'png'}.contains(extension)) {
    throw FormatException(
      'Formato inválido. Apenas arquivos JPG e PNG são permitidos.',
    );
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw const FormatException('Não foi possível ler o arquivo selecionado.');
  }

  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final width = image.width;
  final height = image.height;
  image.dispose();
  codec.dispose();
  if (width > 1024 || height > 1024) {
    throw FormatException(
      'A dimensão máxima permitida é 1024x1024 pixels. (Imagem: ${width}x$height).',
    );
  }

  final mime = extension == 'png' ? 'image/png' : 'image/jpeg';
  return 'data:$mime;base64,${base64Encode(Uint8List.fromList(bytes))}';
}
