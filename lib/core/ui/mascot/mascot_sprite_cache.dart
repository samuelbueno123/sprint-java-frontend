import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mascot_assets.dart';

/// Frame retangular recortado de uma spritesheet.
class MascotAtlasFrame {
  const MascotAtlasFrame({
    required this.rect,
    required this.durationMs,
  });

  final Rect rect;
  final double durationMs;
}

/// Cache LRU sob demanda (lazy) para imagens de spritesheets e metadados JSON.
/// Evita decodificar todos os spritesheets/GIFs simultaneamente e mantém limite de memória.
class MascotSpriteCache {
  MascotSpriteCache._();

  static final MascotSpriteCache instance = MascotSpriteCache._();

  static const int maxCachedImages = 14;

  final LinkedHashMap<String, ui.Image> _images =
      LinkedHashMap<String, ui.Image>();
  final Map<String, Future<ui.Image?>> _inFlightImages = {};
  final Map<String, List<MascotAtlasFrame>> _frameAtlases = {};
  final Map<String, dynamic> _jsonCache = {};

  /// Retorna imagem já decodificada se disponível de forma síncrona.
  ui.Image? getCachedImage(String assetPath) {
    final existing = _images.remove(assetPath);
    if (existing != null) {
      // Refresh LRU order.
      _images[assetPath] = existing;
    }
    return existing;
  }

  /// Decodifica a imagem sob demanda apenas quando necessária, deduplicando chamadas simultâneas.
  Future<ui.Image?> loadImage(String assetPath) {
    final cached = getCachedImage(assetPath);
    if (cached != null) return SynchronousFuture<ui.Image?>(cached);

    final pending = _inFlightImages[assetPath];
    if (pending != null) return pending;

    final future = _decodeAssetImage(assetPath).whenComplete(() {
      _inFlightImages.remove(assetPath);
    });
    _inFlightImages[assetPath] = future;
    return future;
  }

  Future<ui.Image?> _decodeAssetImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();

      _images.remove(assetPath);
      _images[assetPath] = frame.image;
      while (_images.length > maxCachedImages) {
        final oldestKey = _images.keys.first;
        _images.remove(oldestKey);
      }
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  /// Carrega e memoriza metadados JSON do pacote de assets.
  Future<dynamic> loadJson(String assetPath) async {
    if (_jsonCache.containsKey(assetPath)) return _jsonCache[assetPath];
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      _jsonCache[assetPath] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// Obtém lista de retângulos de frames a partir do JSON correspondente ou grade uniforme.
  Future<List<MascotAtlasFrame>> loadFramesForSpec(
    MascotAnimationSpec spec, {
    MascotVariant variant = MascotVariant.white,
    bool useMaster24FpsAtlas = false,
  }) async {
    final cacheKey =
        '${variant.id}:${useMaster24FpsAtlas ? "master24" : "grid"}:${spec.id}';
    final existing = _frameAtlases[cacheKey];
    if (existing != null) return existing;

    List<MascotAtlasFrame>? parsed;

    if (variant == MascotVariant.green) {
      final json = await loadJson(MascotAssets.greenAtlasJson);
      if (json is Map<String, dynamic>) {
        final animName = _greenAnimName(spec.state);
        final animations = json['animations'] as Map<String, dynamic>?;
        final framesMap = json['frames'] as Map<String, dynamic>?;
        final keys = (animations?[animName] as List?)?.cast<String>() ?? [];
        if (keys.isNotEmpty && framesMap != null) {
          parsed = keys.map((key) {
            final entry = framesMap[key] as Map<String, dynamic>?;
            final f = entry?['frame'] as Map<String, dynamic>?;
            return MascotAtlasFrame(
              rect: Rect.fromLTWH(
                (f?['x'] as num?)?.toDouble() ?? 0,
                (f?['y'] as num?)?.toDouble() ?? 0,
                (f?['w'] as num?)?.toDouble() ?? MascotAssets.frameSize,
                (f?['h'] as num?)?.toDouble() ?? MascotAssets.frameSize,
              ),
              durationMs: 180,
            );
          }).toList();
        }
      }
    } else if (useMaster24FpsAtlas && spec.isCoreState) {
      final json = await loadJson(MascotAssets.white24FpsMasterJson);
      if (json is Map<String, dynamic>) {
        final animations = json['animations'] as Map<String, dynamic>?;
        final animObj = animations?[spec.id] as Map<String, dynamic>?;
        final frames = animObj?['frames'] as List?;
        if (frames != null && frames.isNotEmpty) {
          parsed = frames.map((item) {
            final map = item as Map<String, dynamic>;
            final pos = map['master_pos'] as Map<String, dynamic>?;
            return MascotAtlasFrame(
              rect: Rect.fromLTWH(
                (pos?['x'] as num?)?.toDouble() ?? 0,
                (pos?['y'] as num?)?.toDouble() ?? 0,
                MascotAssets.frameSize,
                MascotAssets.frameSize,
              ),
              durationMs: (map['duration_ms'] as num?)?.toDouble() ?? 41.67,
            );
          }).toList();
        }
      }
    } else {
      final json = await loadJson(spec.jsonAssetPath);
      if (json is Map<String, dynamic>) {
        final frames = json['frames'] as List?;
        if (frames != null && frames.isNotEmpty) {
          parsed = frames.map((item) {
            final map = item as Map<String, dynamic>;
            final pos = map['grid_pos'] as Map<String, dynamic>?;
            return MascotAtlasFrame(
              rect: Rect.fromLTWH(
                (pos?['x'] as num?)?.toDouble() ?? 0,
                (pos?['y'] as num?)?.toDouble() ?? 0,
                MascotAssets.frameSize,
                MascotAssets.frameSize,
              ),
              durationMs: (map['duration_ms'] as num?)?.toDouble() ?? 41.67,
            );
          }).toList();
        }
      }
    }

    final resolved = parsed ?? _buildFallbackGridFrames(spec);
    _frameAtlases[cacheKey] = resolved;
    return resolved;
  }

  String _greenAnimName(MascotState state) {
    switch (state) {
      case MascotState.idle:
      case MascotState.clickPoke:
      case MascotState.clickBleat:
      case MascotState.clickHeart:
      case MascotState.holdGrab:
        return 'idle';
      case MascotState.celebrate:
      case MascotState.clickSpin:
      case MascotState.dragStartRight:
      case MascotState.dragMoveRight:
      case MascotState.dragStartUp:
      case MascotState.dragMoveUp:
        return 'celebrate';
      case MascotState.sad:
      case MascotState.wallHitBottom:
      case MascotState.wallHitLeft:
      case MascotState.wallHitRight:
      case MascotState.wallHitTop:
      case MascotState.dragStartLeft:
      case MascotState.dragMoveLeft:
      case MascotState.dragStartDown:
      case MascotState.dragMoveDown:
        return 'sad';
      case MascotState.intense:
      case MascotState.fireLoop:
      case MascotState.clickShake:
        return 'intense';
    }
  }

  List<MascotAtlasFrame> _buildFallbackGridFrames(MascotAnimationSpec spec) {
    return List<MascotAtlasFrame>.generate(spec.frameCount, (i) {
      final col = i % spec.cols;
      final row = i ~/ spec.cols;
      return MascotAtlasFrame(
        rect: Rect.fromLTWH(
          col * MascotAssets.frameSize,
          row * MascotAssets.frameSize,
          MascotAssets.frameSize,
          MascotAssets.frameSize,
        ),
        durationMs: 1000.0 / spec.fps,
      );
    });
  }

  @visibleForTesting
  void clearForTesting() {
    _images.clear();
    _inFlightImages.clear();
    _frameAtlases.clear();
    _jsonCache.clear();
  }
}
