import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mascot_assets.dart';

class MascotLoadedSpriteSheet {
  const MascotLoadedSpriteSheet({
    required this.image,
    required this.frameCount,
    required this.columns,
    required this.rows,
    required this.frameWidth,
    required this.frameHeight,
    required this.fps,
  });

  final ui.Image image;
  final int frameCount;
  final int columns;
  final int rows;
  final int frameWidth;
  final int frameHeight;
  final int fps;
}

class MascotSpriteCache {
  MascotSpriteCache._();

  static final MascotSpriteCache instance = MascotSpriteCache._();

  final Map<String, ui.Image> _images = <String, ui.Image>{};
  final Map<String, Future<ui.Image?>> _inFlightImages =
      <String, Future<ui.Image?>>{};
  final Map<String, Map<String, dynamic>> _jsonCache =
      <String, Map<String, dynamic>>{};

  Future<ui.Image?> loadImage(String assetPath) {
    final existing = _images[assetPath];
    if (existing != null) {
      return SynchronousFuture<ui.Image?>(existing);
    }
    return _inFlightImages.putIfAbsent(assetPath, () async {
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final decoded = frame.image;
        _images[assetPath] = decoded;
        return decoded;
      } catch (_) {
        return null;
      } finally {
        _inFlightImages.remove(assetPath);
      }
    });
  }

  Future<Map<String, dynamic>?> loadJson(String assetPath) async {
    final existing = _jsonCache[assetPath];
    if (existing != null) return existing;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        _jsonCache[assetPath] = parsed;
        return parsed;
      }
    } catch (_) {}
    return null;
  }

  Future<MascotLoadedSpriteSheet?> loadSpriteSheet(
    MascotStateSpec spec, {
    String? overrideSheetPath,
  }) async {
    final path = overrideSheetPath ?? spec.spriteSheetPath;
    final imgFuture = loadImage(path);
    final jsonFuture = loadJson(spec.jsonPath);
    final img = await imgFuture;
    if (img == null) return null;
    final meta = await jsonFuture;

    final frameSize = meta?['frame_size'];
    final grid = meta?['grid'];
    final int fw = (frameSize is Map && frameSize['w'] is num)
        ? (frameSize['w'] as num).toInt()
        : spec.frameWidth;
    final int fh = (frameSize is Map && frameSize['h'] is num)
        ? (frameSize['h'] as num).toInt()
        : spec.frameHeight;
    final int count = meta?['total_frames'] is num
        ? (meta!['total_frames'] as num).toInt()
        : spec.frameCount;
    final int cols = (grid is Map && grid['cols'] is num)
        ? (grid['cols'] as num).toInt()
        : spec.columns;
    final int rows = (grid is Map && grid['rows'] is num)
        ? (grid['rows'] as num).toInt()
        : spec.rows;
    final int fps = meta?['fps'] is num
        ? (meta!['fps'] as num).toInt()
        : spec.fps;

    return MascotLoadedSpriteSheet(
      image: img,
      frameCount: count > 0 ? count : 1,
      columns: cols > 0 ? cols : 1,
      rows: rows > 0 ? rows : 1,
      frameWidth: fw > 0 ? fw : 256,
      frameHeight: fh > 0 ? fh : 256,
      fps: fps > 0 ? fps : 24,
    );
  }

  Future<void> warmUpAll() async {
    await Future.wait([
      for (final spec in MascotAssets.specs.values)
        loadSpriteSheet(spec).catchError((_) => null),
    ]);
  }

  @visibleForTesting
  void clearForTesting() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    _inFlightImages.clear();
    _jsonCache.clear();
  }
}
