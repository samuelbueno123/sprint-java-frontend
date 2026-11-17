import 'dart:async';

import 'package:flutter/material.dart';

import '../motion_kit.dart';
import 'mascot_assets.dart';
import 'mascot_preference_controller.dart';
import 'mascot_sprite_cache.dart';

/// Core Duo Goat sprite renderer powered by assets/duo_goat_spritesheet/.
/// Uses smooth 24fps spritesheet frames (`CustomPaint`) when `useSpriteSheet`
/// or `useMaster24FpsAtlas` is enabled, and clean animated GIF / still fallback.
class MascotSprite extends StatefulWidget {
  const MascotSprite({
    super.key,
    required this.state,
    this.size = 96,
    this.fit = BoxFit.contain,
    this.useSpriteSheet = false,
    this.useMaster24FpsAtlas = false,
    this.animate = true,
    this.overrideVariant,
    this.overrideFps,
    this.explicitGifPath,
    this.onOneShotComplete,
    this.onCompleted,
    this.semanticLabel,
    this.frameColorFilter,
    this.glowColor,
    this.onTap,
  });

  final MascotState state;
  final double size;
  final BoxFit fit;
  final bool useSpriteSheet;
  final bool useMaster24FpsAtlas;
  final bool animate;
  final MascotVariant? overrideVariant;
  final int? overrideFps;
  final String? explicitGifPath;
  final VoidCallback? onOneShotComplete;
  final VoidCallback? onCompleted;
  final String? semanticLabel;
  final ColorFilter? frameColorFilter;
  final Color? glowColor;
  final VoidCallback? onTap;

  @override
  State<MascotSprite> createState() => _MascotSpriteState();
}

class _MascotSpriteState extends State<MascotSprite>
    with SingleTickerProviderStateMixin {
  AnimationController? _sheetController;
  MascotLoadedSpriteSheet? _loadedSheet;
  bool _oneShotReported = false;
  Timer? _gifOneShotTimer;

  bool get _useSheet => widget.useSpriteSheet || widget.useMaster24FpsAtlas;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(covariant MascotSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state ||
        oldWidget.useSpriteSheet != widget.useSpriteSheet ||
        oldWidget.useMaster24FpsAtlas != widget.useMaster24FpsAtlas ||
        oldWidget.animate != widget.animate ||
        oldWidget.overrideFps != widget.overrideFps) {
      _oneShotReported = false;
      _gifOneShotTimer?.cancel();
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _gifOneShotTimer?.cancel();
    _sheetController?.dispose();
    super.dispose();
  }

  Future<void> _setupAnimation() async {
    final spec = MascotAssets.specFor(widget.state);
    final hasCompletionCallback =
        widget.onOneShotComplete != null || widget.onCompleted != null;
    if (!spec.loop && hasCompletionCallback && !_useSheet) {
      final effectiveFps = (widget.overrideFps ?? spec.fps).clamp(4, 36);
      final ms = ((spec.frameCount / effectiveFps) * 1000).round();
      _gifOneShotTimer?.cancel();
      _gifOneShotTimer = Timer(Duration(milliseconds: ms + 40), () {
        if (!mounted || _oneShotReported) return;
        _oneShotReported = true;
        widget.onOneShotComplete?.call();
        widget.onCompleted?.call();
      });
    }

    if (!_useSheet) {
      _sheetController?.stop();
      return;
    }

    final loaded = await MascotSpriteCache.instance.loadSpriteSheet(spec);
    if (!mounted) return;
    setState(() => _loadedSheet = loaded);

    if (loaded == null) return;
    final fps =
        (widget.overrideFps ??
                MascotPreferenceController.targetFps.value)
            .clamp(4, 36);
    final durationMs =
        ((loaded.frameCount / fps) * 1000).round().clamp(160, 8000);

    _sheetController ??= AnimationController(vsync: this);
    _sheetController!.duration = Duration(milliseconds: durationMs);
    _sheetController!.removeStatusListener(_onControllerStatus);
    _sheetController!.addStatusListener(_onControllerStatus);

    if (!widget.animate || isWidgetTestEnvironment) {
      _sheetController!.value = 0;
      _sheetController!.stop();
      return;
    }

    if (spec.loop) {
      _sheetController!.repeat();
    } else {
      _sheetController!.forward(from: 0);
    }
  }

  void _onControllerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_oneShotReported) {
      _oneShotReported = true;
      widget.onOneShotComplete?.call();
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MascotVariant>(
      valueListenable: MascotPreferenceController.variant,
      builder: (context, prefVariant, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: MascotPreferenceController.animationsEnabled,
          builder: (context, animEnabled, _) {
            final effectiveVariant = widget.overrideVariant ?? prefVariant;
            final isFire =
                effectiveVariant == MascotVariant.fire ||
                widget.state == MascotState.fireLoop;
            final spec = MascotAssets.specFor(widget.state);
            final canAnimate =
                widget.animate &&
                animEnabled &&
                MascotPreferenceController.shouldAnimate(context);

            Widget visual;
            if (_useSheet && _loadedSheet != null) {
              visual = AnimatedBuilder(
                animation: _sheetController!,
                builder: (_, _) {
                  final rawValue = canAnimate ? _sheetController!.value : 0.0;
                  final idx =
                      (rawValue * _loadedSheet!.frameCount)
                          .floor()
                          .clamp(0, _loadedSheet!.frameCount - 1);
                  return CustomPaint(
                    size: Size.square(widget.size),
                    painter: _GridSpritePainter(
                      sheet: _loadedSheet!,
                      frameIndex: idx,
                      colorFilter: widget.frameColorFilter,
                    ),
                  );
                },
              );
            } else if (!canAnimate) {
              if (_loadedSheet != null) {
                visual = CustomPaint(
                  size: Size.square(widget.size),
                  painter: _GridSpritePainter(
                    sheet: _loadedSheet!,
                    frameIndex: 0,
                    colorFilter: widget.frameColorFilter,
                  ),
                );
              } else {
                visual = Image.asset(
                  widget.explicitGifPath ?? spec.gifPath,
                  width: widget.size,
                  height: widget.size,
                  fit: widget.fit,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => _MascotFallbackAvatar(
                    size: widget.size,
                    state: widget.state,
                  ),
                );
              }
            } else {
              visual = Image.asset(
                widget.explicitGifPath ?? spec.gifPath,
                width: widget.size,
                height: widget.size,
                fit: widget.fit,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _MascotFallbackAvatar(
                  size: widget.size,
                  state: widget.state,
                ),
              );
            }

            if (isFire || widget.glowColor != null) {
              final primaryGlow =
                  widget.glowColor ?? const Color(0xFFFF6B00);
              visual = DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryGlow.withValues(alpha: 0.34),
                      blurRadius: widget.size * 0.28,
                      spreadRadius: 1,
                    ),
                    if (isFire)
                      BoxShadow(
                        color: const Color(0xFFFACC15).withValues(alpha: 0.25),
                        blurRadius: widget.size * 0.14,
                      ),
                  ],
                ),
                child: visual,
              );
            }

            final wrapped = Semantics(
              label: widget.semanticLabel ?? spec.title,
              image: true,
              button: widget.onTap != null,
              child: SizedBox.square(dimension: widget.size, child: visual),
            );
            if (widget.onTap != null) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: wrapped,
              );
            }
            return wrapped;
          },
        );
      },
    );
  }
}

class _GridSpritePainter extends CustomPainter {
  const _GridSpritePainter({
    required this.sheet,
    required this.frameIndex,
    this.colorFilter,
  });

  final MascotLoadedSpriteSheet sheet;
  final int frameIndex;
  final ColorFilter? colorFilter;

  @override
  void paint(Canvas canvas, Size size) {
    final safeIdx = frameIndex.clamp(0, sheet.frameCount - 1);
    final col = safeIdx % sheet.columns;
    final row = safeIdx ~/ sheet.columns;
    final src = Rect.fromLTWH(
      (col * sheet.frameWidth).toDouble(),
      (row * sheet.frameHeight).toDouble(),
      sheet.frameWidth.toDouble(),
      sheet.frameHeight.toDouble(),
    );
    final dst = Offset.zero & size;
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = colorFilter;
    canvas.drawImageRect(sheet.image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _GridSpritePainter oldDelegate) =>
      oldDelegate.sheet.image != sheet.image ||
      oldDelegate.frameIndex != frameIndex ||
      oldDelegate.colorFilter != colorFilter;
}

class _MascotFallbackAvatar extends StatelessWidget {
  const _MascotFallbackAvatar({required this.size, required this.state});

  final double size;
  final MascotState state;

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      MascotState.celebrate || MascotState.clickHeart => Icons.auto_awesome_rounded,
      MascotState.sad => Icons.sentiment_dissatisfied_rounded,
      MascotState.fireLoop => Icons.local_fire_department_rounded,
      _ => Icons.pets_rounded,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
      ),
      child: Icon(
        icon,
        size: size * 0.48,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class MascotGifBadge extends StatelessWidget {
  const MascotGifBadge({
    super.key,
    required this.state,
    this.size = 64,
    this.overrideVariant,
    this.accentColor,
  });

  final MascotState state;
  final double size;
  final MascotVariant? overrideVariant;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return MascotSprite(
      state: state,
      size: size,
      overrideVariant: overrideVariant,
      glowColor: accentColor,
      useSpriteSheet: false,
    );
  }
}

class MascotPoseEmblem extends StatelessWidget {
  const MascotPoseEmblem({
    super.key,
    required this.state,
    this.size = 44,
    this.backgroundColor,
    this.borderColor,
    this.glowColor,
    this.onTap,
    this.semanticLabel,
  });

  final MascotState state;
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? glowColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final box = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
          color: borderColor ?? colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: MascotSprite(
        state: state,
        size: size * 0.84,
        glowColor: glowColor,
        semanticLabel: semanticLabel,
        useSpriteSheet: true,
      ),
    );
    if (onTap == null) return box;
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(size * 0.3),
        onTap: onTap,
        child: box,
      ),
    );
  }
}

class MascotLoader extends StatelessWidget {
  const MascotLoader({
    super.key,
    this.message = 'Carregando...',
    this.subtitle,
    this.state = MascotState.idle,
    this.mascotSize = 92,
    this.useSpriteSheet = false,
    this.accentColor,
    this.showProgressBar = true,
    this.compact = false,
  });

  final String message;
  final String? subtitle;
  final MascotState state;
  final double mascotSize;
  final bool useSpriteSheet;
  final Color? accentColor;
  final bool showProgressBar;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotSprite(
              state: state,
              size: mascotSize,
              useSpriteSheet: useSpriteSheet,
              glowColor: accentColor,
            ),
            SizedBox(height: compact ? 8 : 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (showProgressBar) ...[
              SizedBox(height: compact ? 8 : 14),
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: accentColor,
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

class MascotEmptyIllustration extends StatelessWidget {
  const MascotEmptyIllustration({
    super.key,
    this.title = 'Nada por aqui ainda',
    this.message,
    this.subtitle,
    this.state = MascotState.idle,
    this.size = 94,
    this.mascotSize,
    this.action,
    this.accentColor,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? subtitle;
  final MascotState state;
  final double size;
  final double? mascotSize;
  final Widget? action;
  final Color? accentColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveSubtitle = message ?? subtitle;
    final resolvedSize = mascotSize ?? size;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotSprite(
              state: state,
              size: resolvedSize,
              glowColor: accentColor,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (effectiveSubtitle != null && effectiveSubtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                effectiveSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ] else if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                style: accentColor == null
                    ? null
                    : FilledButton.styleFrom(backgroundColor: accentColor),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MascotErrorIllustration extends StatelessWidget {
  const MascotErrorIllustration({
    super.key,
    this.title = 'Algo saiu do esperado',
    this.message = 'Tente novamente em alguns instantes.',
    this.state = MascotState.sad,
    this.size = 92,
    this.onRetry,
    this.retryLabel = 'Tentar novamente',
    this.accentColor,
  });

  final String title;
  final String message;
  final MascotState state;
  final double size;
  final VoidCallback? onRetry;
  final String retryLabel;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotSprite(state: state, size: size, glowColor: accentColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                style: accentColor == null
                    ? null
                    : FilledButton.styleFrom(backgroundColor: accentColor),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MascotSpeechBanner extends StatelessWidget {
  const MascotSpeechBanner({
    super.key,
    required this.message,
    this.title,
    this.state = MascotState.clickBleat,
    this.accentColor,
    this.trailing,
    this.mascotSize = 62,
  });

  final String message;
  final String? title;
  final MascotState state;
  final Color? accentColor;
  final Widget? trailing;
  final double mascotSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = accentColor ?? colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          MascotSprite(state: state, size: mascotSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null && title!.isNotEmpty) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
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
