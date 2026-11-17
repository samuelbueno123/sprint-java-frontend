import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../audio/system_sound_service.dart';
import '../motion_kit.dart';
import 'mascot_assets.dart';
import 'mascot_preference_controller.dart';
import 'mascot_sprite_cache.dart';
import 'mascot_sprite_widget.dart';

/// Physics-enabled interactive Duo Goat stage faithful to
/// `assets/duo_goat_spritesheet/index.html`:
/// - Tap cycles 5 click animations (`clickPoke`, `clickHeart`, `clickSpin`,
///   `clickBleat`, `clickShake`) + SFX
/// - Hold >= 250ms triggers `holdGrab`
/// - Drag transitions directional `dragStart*` -> `dragMove*`
/// - Release throws with velocity, damping (0.90), and sandbox wall collisions
///   (`wallHitRight`, `wallHitLeft`, `wallHitTop`, `wallHitBottom`) + splat SFX
/// - Optional Fire Streak mode (`fireLoop`) with animated aura.
class InteractiveMascotStage extends StatefulWidget {
  const InteractiveMascotStage({
    super.key,
    this.size = 112,
    this.mascotSize,
    this.height,
    this.initialState = MascotState.idle,
    this.initialQuote,
    this.hintText,
    this.onStateTriggered,
    this.onReaction,
    this.accentColor = const Color(0xFF4F46E5),
    this.fireMode = false,
    this.compact = false,
    this.showControls = true,
    this.sandboxBounds = const Size(240, 150),
  });

  final double size;
  final double? mascotSize;
  final double? height;
  final MascotState initialState;
  final String? initialQuote;
  final String? hintText;
  final void Function(MascotState state)? onStateTriggered;
  final void Function(MascotState state)? onReaction;
  final Color accentColor;
  final bool fireMode;
  final bool compact;
  final bool showControls;
  final Size sandboxBounds;

  double get resolvedSize => mascotSize ?? size;

  Size get resolvedBounds => Size(
    sandboxBounds.width,
    height ?? sandboxBounds.height,
  );

  @override
  State<InteractiveMascotStage> createState() => _InteractiveMascotStageState();
}

class _InteractiveMascotStageState extends State<InteractiveMascotStage>
    with SingleTickerProviderStateMixin {
  late MascotState _currentState;
  late String _quote;
  late bool _fireMode;
  int _clickIndex = 0;
  DateTime? _lastTapAt;

  Offset _position = Offset.zero;
  Offset _velocity = Offset.zero;
  bool _isDragging = false;
  DateTime? _dragStartTime;
  Timer? _holdTimer;
  Timer? _resetTimer;
  Ticker? _physicsTicker;

  @override
  void initState() {
    super.initState();
    _fireMode = widget.fireMode;
    _currentState =
        _fireMode && widget.initialState == MascotState.idle
            ? MascotState.fireLoop
            : widget.initialState;
    _quote =
        widget.initialQuote ??
        widget.hintText ??
        MascotAssets.specFor(_currentState).defaultQuote;
    _physicsTicker = createTicker(_onPhysicsTick);
  }

  @override
  void didUpdateWidget(covariant InteractiveMascotStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fireMode != widget.fireMode) {
      _fireMode = widget.fireMode;
      if (_fireMode && _currentState == MascotState.idle) {
        _currentState = MascotState.fireLoop;
      } else if (!_fireMode && _currentState == MascotState.fireLoop) {
        _currentState = widget.initialState;
      }
    }
    if (oldWidget.initialState != widget.initialState && !_isDragging) {
      _currentState =
          _fireMode && widget.initialState == MascotState.idle
              ? MascotState.fireLoop
              : widget.initialState;
      _quote =
          widget.initialQuote ??
          widget.hintText ??
          MascotAssets.specFor(_currentState).defaultQuote;
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _resetTimer?.cancel();
    _physicsTicker?.dispose();
    super.dispose();
  }

  MascotState get _restingState =>
      _fireMode ? MascotState.fireLoop : widget.initialState;

  void _triggerState(
    MascotState next, {
    Duration? autoResetAfter,
    bool playSound = true,
  }) {
    _resetTimer?.cancel();
    final spec = MascotAssets.specFor(next);
    if (playSound && spec.sfx != null) {
      SystemSoundService.play(spec.sfx!);
    }
    if (!mounted) return;
    setState(() {
      _currentState = next;
      _quote = spec.defaultQuote;
    });
    widget.onStateTriggered?.call(next);
    widget.onReaction?.call(next);

    if (autoResetAfter != null && !isWidgetTestEnvironment) {
      _resetTimer = Timer(autoResetAfter, () {
        if (!mounted || _isDragging) return;
        setState(() => _currentState = _restingState);
      });
    }
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!) <= const Duration(milliseconds: 320)) {
      _lastTapAt = null;
      _toggleFireMode();
      return;
    }
    _lastTapAt = now;
    final reactions = MascotAssets.clickReactions;
    final reaction = reactions[_clickIndex % reactions.length];
    _clickIndex++;
    _triggerState(
      reaction,
      autoResetAfter: const Duration(milliseconds: 850),
    );
  }

  void _startHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || _isDragging) return;
      _triggerState(MascotState.holdGrab);
    });
  }

  void _onPanStart(DragStartDetails details) {
    _holdTimer?.cancel();
    _resetTimer?.cancel();
    _physicsTicker?.stop();
    _isDragging = true;
    _dragStartTime = DateTime.now();
    _velocity = Offset.zero;
    _triggerState(MascotState.holdGrab, playSound: true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final bounds = widget.resolvedBounds;
    final itemSize = widget.resolvedSize;
    final maxX = math.max(24.0, (bounds.width - itemSize) / 2);
    final maxY = math.max(18.0, (bounds.height - itemSize) / 2);
    final rawNext = _position + details.delta;
    final clampedX = rawNext.dx.clamp(-maxX, maxX);
    final clampedY = rawNext.dy.clamp(-maxY, maxY);

    MascotState? wallHit;
    if (rawNext.dx > maxX) {
      wallHit = MascotState.wallHitRight;
    } else if (rawNext.dx < -maxX) {
      wallHit = MascotState.wallHitLeft;
    } else if (rawNext.dy < -maxY) {
      wallHit = MascotState.wallHitTop;
    } else if (rawNext.dy > maxY) {
      wallHit = MascotState.wallHitBottom;
    }

    setState(() {
      _position = Offset(clampedX, clampedY);
      _velocity = details.delta * 0.85;
    });

    if (wallHit != null) {
      _triggerState(wallHit, playSound: _currentState != wallHit);
      return;
    }

    final dx = details.delta.dx;
    final dy = details.delta.dy;
    if (dx.abs() < 0.8 && dy.abs() < 0.8) return;

    final elapsedMs = _dragStartTime == null
        ? 300
        : DateTime.now().difference(_dragStartTime!).inMilliseconds;
    final isStartPhase = elapsedMs < 240;

    MascotState dirState;
    if (dx.abs() >= dy.abs()) {
      if (dx >= 0) {
        dirState = isStartPhase
            ? MascotState.dragStartRight
            : MascotState.dragMoveRight;
      } else {
        dirState = isStartPhase
            ? MascotState.dragStartLeft
            : MascotState.dragMoveLeft;
      }
    } else {
      if (dy < 0) {
        dirState = isStartPhase
            ? MascotState.dragStartUp
            : MascotState.dragMoveUp;
      } else {
        dirState = isStartPhase
            ? MascotState.dragStartDown
            : MascotState.dragMoveDown;
      }
    }

    if (_currentState != dirState) {
      _triggerState(dirState, playSound: false);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    final vel = details.velocity.pixelsPerSecond / 60.0;
    _velocity = Offset(
      vel.dx.clamp(-18.0, 18.0),
      vel.dy.clamp(-18.0, 18.0),
    );
    if (_velocity.distance > 1.2) {
      _physicsTicker?.stop();
      _physicsTicker?.start();
    } else {
      _snapBackHome();
    }
  }

  void _onPhysicsTick(Duration elapsed) {
    if (!mounted || _isDragging) return;
    final bounds = widget.resolvedBounds;
    final itemSize = widget.resolvedSize;
    final maxX = math.max(24.0, (bounds.width - itemSize) / 2);
    final maxY = math.max(18.0, (bounds.height - itemSize) / 2);

    var nx = _position.dx + _velocity.dx;
    var ny = _position.dy + _velocity.dy;
    var vx = _velocity.dx * 0.90;
    var vy = _velocity.dy * 0.90;

    MascotState? hit;
    if (nx > maxX) {
      nx = maxX;
      vx = -vx.abs() * 0.7;
      hit = MascotState.wallHitRight;
    } else if (nx < -maxX) {
      nx = -maxX;
      vx = vx.abs() * 0.7;
      hit = MascotState.wallHitLeft;
    }
    if (ny > maxY) {
      ny = maxY;
      vy = -vy.abs() * 0.7;
      hit ??= MascotState.wallHitBottom;
    } else if (ny < -maxY) {
      ny = -maxY;
      vy = vy.abs() * 0.7;
      hit ??= MascotState.wallHitTop;
    }

    // Gentle spring pull back toward center once kinetic throw slows down.
    nx *= 0.93;
    ny *= 0.93;

    setState(() {
      _position = Offset(nx, ny);
      _velocity = Offset(vx, vy);
    });

    if (hit != null && _currentState != hit) {
      _triggerState(hit, autoResetAfter: const Duration(milliseconds: 520));
    }

    if (_velocity.distance < 0.25 && _position.distance < 1.2) {
      _physicsTicker?.stop();
      setState(() {
        _position = Offset.zero;
        _velocity = Offset.zero;
        _currentState = _restingState;
      });
    }
  }

  void _snapBackHome() {
    _physicsTicker?.stop();
    setState(() => _position = Offset.zero);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _currentState = _restingState);
    });
  }

  void _toggleFireMode() {
    setState(() {
      _fireMode = !_fireMode;
    });
    if (_fireMode) {
      _triggerState(MascotState.fireLoop);
    } else {
      _triggerState(MascotState.idle, playSound: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spec = MascotAssets.specFor(_currentState);

    final interactiveMascot = Listener(
      onPointerDown: (_) => _startHoldTimer(),
      onPointerUp: (_) => _holdTimer?.cancel(),
      onPointerCancel: (_) => _holdTimer?.cancel(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Transform.translate(
          offset: _position,
          child: MascotSprite(
            state: _currentState,
            size: widget.resolvedSize,
            overrideVariant: _fireMode ? MascotVariant.fire : null,
            useSpriteSheet: false,
            onOneShotComplete: () {
              if (!mounted || _isDragging) return;
              if (!spec.loop) {
                setState(() => _currentState = _restingState);
              }
            },
          ),
        ),
      ),
    );

    if (widget.compact) {
      return interactiveMascot;
    }

    final bounds = widget.resolvedBounds;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _fireMode
              ? const Color(0xFFFF6B00).withValues(alpha: 0.55)
              : widget.accentColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: bounds.width,
            height: bounds.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _fireMode
                    ? [
                        const Color(0xFFFF6B00).withValues(alpha: 0.14),
                        const Color(0xFFFACC15).withValues(alpha: 0.08),
                      ]
                    : [
                        widget.accentColor.withValues(alpha: 0.07),
                        colors.surface.withValues(alpha: 0.7),
                      ],
              ),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: interactiveMascot,
          ),
          if (_fireMode) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFFFF6B00).withValues(alpha: 0.45),
                ),
              ),
              child: const Text(
                'Modo Chama Ativo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFC2410C),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            _quote,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          if (widget.showControls) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Foco'),
                  onPressed: () => _triggerState(
                    MascotState.intense,
                    autoResetAfter: const Duration(milliseconds: 1400),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.celebration_rounded, size: 16),
                  label: const Text('Comemorar'),
                  onPressed: () => _triggerState(
                    MascotState.celebrate,
                    autoResetAfter: const Duration(milliseconds: 1200),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.favorite_rounded, size: 16),
                  label: const Text('Carinho'),
                  onPressed: () => _triggerState(
                    MascotState.clickHeart,
                    autoResetAfter: const Duration(milliseconds: 950),
                  ),
                ),
                FilterChip(
                  avatar: const Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                  ),
                  label: const Text('Modo Fogo'),
                  selected: _fireMode,
                  onSelected: (_) => _toggleFireMode(),
                ),
                ActionChip(
                  avatar: const Icon(Icons.grid_view_rounded, size: 16),
                  label: const Text('23 Poses'),
                  onPressed: () {
                    SystemSoundService.click();
                    MascotCompanionModal.show(context);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Interactive Studio showcase modeled directly after
/// `assets/duo_goat_spritesheet/index.html`, letting users inspect & interact
/// with all 23 animations, playback speed (4-30 FPS), checker transparency, and
/// live physics sandbox.
class MascotCompanionModal extends StatefulWidget {
  const MascotCompanionModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const MascotCompanionModal(),
    );
  }

  @override
  State<MascotCompanionModal> createState() => _MascotCompanionModalState();
}

class _MascotCompanionModalState extends State<MascotCompanionModal> {
  MascotState _selectedState = MascotState.idle;
  String _selectedCategory = 'Todos';
  bool _useSpriteSheet = false;
  bool _checkerBg = true;
  bool _fireMode = false;
  double _fps = 24;

  late final List<String> _categories = [
    'Todos',
    ...MascotAssets.specs.values.map((s) => s.category).toSet(),
  ];

  @override
  void initState() {
    super.initState();
    _fps = MascotPreferenceController.targetFps.value.toDouble();
    _fireMode = MascotPreferenceController.variant.value == MascotVariant.fire;
    unawaited(_warmCatalog());
  }

  Future<void> _warmCatalog() async {
    final cache = MascotSpriteCache.instance;
    await Future.wait([
      cache.loadJson(MascotAssets.catalog24FpsJson),
      cache.loadJson(MascotAssets.catalogInteractiveJson),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final allSpecs = MascotAssets.specs.values.toList();
    final filtered = _selectedCategory == 'Todos'
        ? allSpecs
        : allSpecs.where((s) => s.category == _selectedCategory).toList();
    final selectedSpec = MascotAssets.specFor(_selectedState);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: ValueListenableBuilder<MascotVariant>(
          valueListenable: MascotPreferenceController.variant,
          builder: (context, currentVariant, _) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Estúdio Interativo Duo Goat — 23 Animações',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          SystemSoundService.click();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final v in MascotVariant.values)
                        ChoiceChip(
                          avatar: MascotSprite(
                            state: v == MascotVariant.fire
                                ? MascotState.fireLoop
                                : MascotState.idle,
                            size: 22,
                            overrideVariant: v,
                          ),
                          label: Text(MascotAssets.variantName(v)),
                          selected: currentVariant == v,
                          onSelected: (_) {
                            SystemSoundService.pop();
                            MascotPreferenceController.setVariant(v);
                            setState(() => _fireMode = v == MascotVariant.fire);
                          },
                        ),
                      FilterChip(
                        label: const Text('Modo Spritesheet'),
                        selected: _useSpriteSheet,
                        onSelected: (v) {
                          SystemSoundService.click();
                          setState(() => _useSpriteSheet = v);
                        },
                      ),
                      FilterChip(
                        label: const Text('Fundo Xadrez'),
                        selected: _checkerBg,
                        onSelected: (v) {
                          SystemSoundService.click();
                          setState(() => _checkerBg = v);
                        },
                      ),
                      FilterChip(
                        avatar: const Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                        ),
                        label: const Text('Fogo'),
                        selected: _fireMode,
                        onSelected: (v) {
                          SystemSoundService.play(
                            v ? SystemSfxType.fire : SystemSfxType.click,
                          );
                          setState(() {
                            _fireMode = v;
                            if (v) _selectedState = MascotState.fireLoop;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Preview Sandbox & Details
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final previewBox = Container(
                          width: 146,
                          height: 146,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: _checkerBg
                                ? const Color(0xFFF1F5F9)
                                : colors.surface,
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_checkerBg)
                                  const Positioned.fill(
                                    child: CustomPaint(painter: _CheckerPainter()),
                                  ),
                                InteractiveMascotStage(
                                  size: 118,
                                  initialState: _selectedState,
                                  fireMode: _fireMode,
                                  compact: true,
                                  sandboxBounds: const Size(146, 146),
                                  onStateTriggered: (triggered) {
                                    setState(() => _selectedState = triggered);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );

                        final infoCol = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(selectedSpec.category),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    '${selectedSpec.frameCount} frames • ${_fps.round()} FPS',
                                  ),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    selectedSpec.loop ? 'Loop contínuo' : 'One-shot',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              selectedSpec.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${selectedSpec.description} (Toque, segure ou arraste o bode no quadro ao lado!)',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Velocidade: ${_fps.round()} FPS',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    min: 4,
                                    max: 30,
                                    divisions: 26,
                                    value: _fps,
                                    onChanged: (val) {
                                      setState(() => _fps = val);
                                      MascotPreferenceController.setTargetFps(
                                        val.round(),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );

                        if (constraints.maxWidth < 520) {
                          return Column(
                            children: [
                              previewBox,
                              const SizedBox(height: 12),
                              infoCol,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            previewBox,
                            const SizedBox(width: 16),
                            Expanded(child: infoCol),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _categories.map((cat) {
                      return ChoiceChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (_) {
                          SystemSoundService.click();
                          setState(() => _selectedCategory = cat);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 148,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.92,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final spec = filtered[index];
                        final isSelected = spec.state == _selectedState;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            if (spec.sfx != null) {
                              SystemSoundService.play(spec.sfx!);
                            } else {
                              SystemSoundService.pop();
                            }
                            setState(() => _selectedState = spec.state);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.primaryContainer.withValues(alpha: 0.5)
                                  : colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? colors.primary
                                    : colors.outlineVariant,
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                MascotSprite(
                                  state: spec.state,
                                  size: 62,
                                  useSpriteSheet: _useSpriteSheet,
                                  overrideFps: _fps.round(),
                                  overrideVariant: _fireMode
                                      ? MascotVariant.fire
                                      : currentVariant,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  spec.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    final dark = Paint()..color = const Color(0xFFE2E8F0);
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final col = (x / cell).floor();
        final row = (y / cell).floor();
        if ((col + row).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerPainter oldDelegate) => false;
}
