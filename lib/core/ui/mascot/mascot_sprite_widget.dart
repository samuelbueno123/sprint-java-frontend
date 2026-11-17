import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../motion_kit.dart';
import 'mascot_assets.dart';
import 'mascot_preference_controller.dart';
import 'mascot_sprite_cache.dart';

/// Renderiza um sprite ou animação frame-a-frame do mascote a partir das
/// spritesheets oficiais com recorte nítido (`FilterQuality.none`) e
/// carregamento sob demanda (lazy) em cache LRU.
///
/// Respeita automaticamente:
/// - preferência global do usuário (Bode Branco / Bode Verde);
/// - redução de movimento do sistema (`MediaQuery.maybeDisableAnimationsOf`);
/// - pausa segura em ambiente de testes (`isWidgetTestEnvironment`).
class MascotSprite extends StatefulWidget {
  const MascotSprite({
    super.key,
    this.state = MascotState.idle,
    this.size = 72,
    this.overrideVariant,
    this.loop,
    this.staticOnly = false,
    this.useMaster24FpsAtlas = false,
    this.speedMultiplier = 1.0,
    this.flipHorizontally = false,
    this.onCompleted,
    this.onTap,
    this.semanticLabel,
    this.glowColor,
  });

  final MascotState state;
  final double size;
  final MascotVariant? overrideVariant;
  final bool? loop;
  final bool staticOnly;
  final bool useMaster24FpsAtlas;
  final double speedMultiplier;
  final bool flipHorizontally;
  final VoidCallback? onCompleted;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? glowColor;

  @override
  State<MascotSprite> createState() => _MascotSpriteState();
}

class _MascotSpriteState extends State<MascotSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  ui.Image? _sheetImage;
  ui.Image? _fallbackMasterImage;
  List<MascotAtlasFrame> _frames = const [];
  bool _loadFailed = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addStatusListener(_handleAnimationStatus);
    MascotPreferenceController.variant.addListener(_handlePreferenceChanged);
    MascotPreferenceController.animationsEnabled.addListener(
      _handlePreferenceChanged,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadAssets();
  }

  @override
  void didUpdateWidget(covariant MascotSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state ||
        oldWidget.overrideVariant != widget.overrideVariant ||
        oldWidget.staticOnly != widget.staticOnly ||
        oldWidget.useMaster24FpsAtlas != widget.useMaster24FpsAtlas ||
        oldWidget.loop != widget.loop ||
        oldWidget.speedMultiplier != widget.speedMultiplier) {
      _reloadAssets();
    }
  }

  @override
  void dispose() {
    _loadToken++;
    MascotPreferenceController.variant.removeListener(_handlePreferenceChanged);
    MascotPreferenceController.animationsEnabled.removeListener(
      _handlePreferenceChanged,
    );
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  void _handlePreferenceChanged() {
    if (!mounted) return;
    _reloadAssets();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call();
    }
  }

  MascotVariant get _effectiveVariant =>
      widget.overrideVariant ?? MascotPreferenceController.variant.value;

  bool get _shouldAnimate {
    if (widget.staticOnly || isWidgetTestEnvironment) return false;
    final systemReduced =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (systemReduced) return false;
    return MascotPreferenceController.animationsEnabled.value;
  }

  Future<void> _reloadAssets() async {
    final token = ++_loadToken;
    final variant = _effectiveVariant;
    final spec = MascotAssets.specFor(widget.state);
    final animate = _shouldAnimate;
    final cache = MascotSpriteCache.instance;

    final masterPath = MascotAssets.masterSheetFor(variant);
    final cachedMaster = cache.getCachedImage(masterPath);
    if (cachedMaster != null) {
      _fallbackMasterImage = cachedMaster;
    }

    if (!animate) {
      _controller.stop();
      final masterImg = cachedMaster ?? await cache.loadImage(masterPath);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _fallbackMasterImage = masterImg;
        _sheetImage = null;
        _frames = const [];
        _loadFailed = masterImg == null;
      });
      return;
    }

    final sheetPath = variant == MascotVariant.green
        ? MascotAssets.greenMasterSheet
        : (widget.useMaster24FpsAtlas && spec.isCoreState
            ? MascotAssets.white24FpsMasterGrid
            : spec.gridAssetPath);

    // Garante o mestre em cache para exibir pose imediata enquanto a grade decodifica.
    if (_fallbackMasterImage == null) {
      cache.loadImage(masterPath).then((img) {
        if (!mounted || token != _loadToken || img == null) return;
        setState(() {
          _fallbackMasterImage = img;
        });
      });
    }

    final results = await Future.wait<dynamic>([
      cache.loadImage(sheetPath),
      cache.loadFramesForSpec(
        spec,
        variant: variant,
        useMaster24FpsAtlas: widget.useMaster24FpsAtlas,
      ),
    ]);

    if (!mounted || token != _loadToken) return;

    final decodedSheet = results[0] as ui.Image?;
    final loadedFrames = results[1] as List<MascotAtlasFrame>;

    if (decodedSheet == null || loadedFrames.isEmpty) {
      setState(() {
        _sheetImage = null;
        _frames = const [];
        _loadFailed = _fallbackMasterImage == null;
      });
      return;
    }

    final totalMs = loadedFrames.fold<double>(
      0,
      (sum, f) => sum + (f.durationMs <= 0 ? 41.67 : f.durationMs),
    );
    final speed = widget.speedMultiplier <= 0 ? 1.0 : widget.speedMultiplier;
    final durationMs = (totalMs / speed).round().clamp(120, 60000);

    setState(() {
      _sheetImage = decodedSheet;
      _frames = loadedFrames;
      _loadFailed = false;
    });

    _controller.duration = Duration(milliseconds: durationMs);
    final shouldLoop = widget.loop ?? spec.loop;
    _controller.reset();
    if (shouldLoop) {
      _controller.repeat();
    } else {
      _controller.forward(from: 0);
    }
  }

  Rect _masterCellRect(MascotAnimationSpec spec) {
    return Rect.fromLTWH(
      spec.masterCol * MascotAssets.frameSize,
      spec.masterRow * MascotAssets.frameSize,
      MascotAssets.frameSize,
      MascotAssets.frameSize,
    );
  }

  Widget _buildFallbackIcon(MascotAnimationSpec spec) {
    final color = widget.glowColor ?? const Color(0xFF58CC02);
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(
        spec.fallbackIcon,
        size: widget.size * 0.52,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = MascotAssets.specFor(widget.state);

    Widget content;
    if (_sheetImage != null && _frames.isNotEmpty && _shouldAnimate) {
      content = AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final rawIndex = (_controller.value * _frames.length).floor();
          final frameIndex = rawIndex.clamp(0, _frames.length - 1);
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _MascotFramePainter(
              image: _sheetImage!,
              srcRect: _frames[frameIndex].rect,
              flipHorizontally: widget.flipHorizontally,
            ),
          );
        },
      );
    } else if (_fallbackMasterImage != null) {
      content = CustomPaint(
        size: Size.square(widget.size),
        painter: _MascotFramePainter(
          image: _fallbackMasterImage!,
          srcRect: _masterCellRect(spec),
          flipHorizontally: widget.flipHorizontally,
        ),
      );
    } else if (_loadFailed) {
      content = _buildFallbackIcon(spec);
    } else {
      // Espaço reservado suave enquanto o primeiro quadro carrega.
      content = SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: Icon(
            spec.fallbackIcon,
            size: widget.size * 0.45,
            color: (widget.glowColor ?? const Color(0xFF58CC02)).withValues(
              alpha: 0.35,
            ),
          ),
        ),
      );
    }

    if (widget.glowColor != null) {
      content = Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.glowColor!.withValues(alpha: 0.22),
              blurRadius: widget.size * 0.28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: content,
      );
    }

    if (widget.onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: content,
        ),
      );
    }

    return Semantics(
      label: widget.semanticLabel ?? 'Mascote Duolinfo: ${spec.title}',
      image: true,
      button: widget.onTap != null,
      child: RepaintBoundary(child: content),
    );
  }
}

class _MascotFramePainter extends CustomPainter {
  const _MascotFramePainter({
    required this.image,
    required this.srcRect,
    required this.flipHorizontally,
  });

  final ui.Image image;
  final Rect srcRect;
  final bool flipHorizontally;

  @override
  void paint(Canvas canvas, Size size) {
    final dstRect = Offset.zero & size;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    if (flipHorizontally) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
      canvas.drawImageRect(image, srcRect, dstRect, paint);
      canvas.restore();
    } else {
      canvas.drawImageRect(image, srcRect, dstRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MascotFramePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.srcRect != srcRect ||
        oldDelegate.flipHorizontally != flipHorizontally;
  }
}

/// Emblema leve e estático extraído da spritesheet master 4x4, ideal para
/// barras superiores, badges, abas e cartões de feedback sem alocar tickers.
class MascotPoseEmblem extends StatelessWidget {
  const MascotPoseEmblem({
    super.key,
    this.state = MascotState.idle,
    this.size = 36,
    this.overrideVariant,
    this.glowColor,
    this.onTap,
    this.semanticLabel,
  });

  final MascotState state;
  final double size;
  final MascotVariant? overrideVariant;
  final Color? glowColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return MascotSprite(
      state: state,
      size: size,
      overrideVariant: overrideVariant,
      staticOnly: true,
      glowColor: glowColor,
      onTap: onTap,
      semanticLabel: semanticLabel,
    );
  }
}

/// Exibe um GIF oficial do mascote sob demanda, com `FilterQuality.none`,
/// fallback automático para sprite estático em modo de movimento reduzido/testes
/// e fallback visual em caso de erro de carregamento.
class MascotGifBadge extends StatelessWidget {
  const MascotGifBadge({
    super.key,
    this.state = MascotState.idle,
    this.size = 84,
    this.overrideVariant,
    this.explicitGifPath,
    this.staticOnly = false,
    this.onTap,
    this.semanticLabel,
  });

  final MascotState state;
  final double size;
  final MascotVariant? overrideVariant;
  final String? explicitGifPath;
  final bool staticOnly;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MascotVariant>(
      valueListenable: MascotPreferenceController.variant,
      builder: (context, selectedVariant, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: MascotPreferenceController.animationsEnabled,
          builder: (context, _, _) {
            final effectiveVariant = overrideVariant ?? selectedVariant;
            final shouldPlayGif =
                !staticOnly && MascotPreferenceController.shouldAnimate(context);
            final spec = MascotAssets.specFor(state);

            Widget child;
            if (!shouldPlayGif) {
              child = MascotSprite(
                state: state,
                size: size,
                overrideVariant: effectiveVariant,
                staticOnly: true,
                semanticLabel: semanticLabel,
              );
            } else {
              final gifPath =
                  explicitGifPath ??
                  MascotAssets.gifFor(state, variant: effectiveVariant);
              child = Image.asset(
                gifPath,
                width: size,
                height: size,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                gaplessPlayback: true,
                semanticLabel: semanticLabel ?? spec.title,
                errorBuilder: (context, error, stackTrace) {
                  return MascotSprite(
                    state: state,
                    size: size,
                    overrideVariant: effectiveVariant,
                    staticOnly: true,
                    semanticLabel: semanticLabel,
                  );
                },
              );
            }

            if (onTap != null) {
              child = MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: child,
                ),
              );
            }

            return SizedBox(width: size, height: size, child: child);
          },
        );
      },
    );
  }
}

/// Indicador de carregamento animado do Duolinfo que utiliza os GIFs/sprites
/// do mascote no lugar de spinners genéricos em operações assíncronas de tela.
class MascotLoader extends StatelessWidget {
  const MascotLoader({
    super.key,
    this.message = 'Carregando...',
    this.subtitle,
    this.state = MascotState.idle,
    this.mascotSize = 84,
    this.overrideVariant,
    this.compact = false,
    this.showProgressBar = true,
    this.useSpriteSheet = false,
    this.accentColor = const Color(0xFF58CC02),
  });

  final String message;
  final String? subtitle;
  final MascotState state;
  final double mascotSize;
  final MascotVariant? overrideVariant;
  final bool compact;
  final bool showProgressBar;
  final bool useSpriteSheet;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mascotWidget = Container(
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.28 : 0.18),
        ),
      ),
      child: useSpriteSheet
          ? MascotSprite(
              state: state,
              size: mascotSize,
              overrideVariant: overrideVariant,
              useMaster24FpsAtlas: true,
            )
          : MascotGifBadge(
              state: state,
              size: mascotSize,
              overrideVariant: overrideVariant,
            ),
    );

    if (compact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              mascotWidget,
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            mascotWidget,
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
            if (showProgressBar) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: 168,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: isWidgetTestEnvironment
                      ? LinearProgressIndicator(
                          value: 0.55,
                          minHeight: 5,
                          backgroundColor: accentColor.withValues(alpha: 0.16),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                        )
                      : LinearProgressIndicator(
                          minHeight: 5,
                          backgroundColor: accentColor.withValues(alpha: 0.16),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ilustração reutilizável do mascote para estados vazios.
class MascotEmptyIllustration extends StatelessWidget {
  const MascotEmptyIllustration({
    super.key,
    this.state = MascotState.idle,
    this.size = 92,
    this.accentColor,
  });

  final MascotState state;
  final double size;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = accentColor ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.28 : 0.18),
        ),
      ),
      child: MascotSprite(
        state: state,
        size: size,
        glowColor: color,
      ),
    );
  }
}

/// Ilustração do mascote para estados de erro e tentativas de reconexão.
class MascotErrorIllustration extends StatelessWidget {
  const MascotErrorIllustration({
    super.key,
    this.state = MascotState.sad,
    this.size = 88,
  });

  final MascotState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: isDark ? 0.18 : 0.09),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: isDark ? 0.35 : 0.22),
        ),
      ),
      child: MascotGifBadge(
        state: state,
        size: size,
      ),
    );
  }
}

/// Banner narrativo reutilizável com o mascote e balão de fala/dica contextual.
class MascotSpeechBanner extends StatelessWidget {
  const MascotSpeechBanner({
    super.key,
    required this.title,
    required this.message,
    this.state = MascotState.idle,
    this.mascotSize = 64,
    this.accentColor = const Color(0xFF58CC02),
    this.trailing,
    this.onMascotTap,
  });

  final String title;
  final String message;
  final MascotState state;
  final double mascotSize;
  final Color accentColor;
  final Widget? trailing;
  final VoidCallback? onMascotTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? accentColor.withValues(alpha: 0.12)
            : accentColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.28 : 0.22),
        ),
      ),
      child: Row(
        children: [
          MascotSprite(
            state: state,
            size: mascotSize,
            onTap: onMascotTap,
            glowColor: accentColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: isDark ? Colors.grey[200] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
