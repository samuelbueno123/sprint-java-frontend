import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mascot_assets.dart';
import 'mascot_preference_controller.dart';
import 'mascot_sprite_cache.dart';
import 'mascot_sprite_widget.dart';

/// Palco interativo do mascote com suporte a toque (reações aleatórias),
/// pressão longa (`hold_grab`), arraste direcional nas 4 direções
/// (`drag_start_*` / `drag_move_*`), colisão com bordas (`wall_hit_*`)
/// e modo de ofensiva (`fire_loop` / `intense`).
class InteractiveMascotStage extends StatefulWidget {
  const InteractiveMascotStage({
    super.key,
    this.initialState = MascotState.idle,
    this.mascotSize = 96,
    this.height = 176,
    this.fireMode = false,
    this.showSpeechBubble = true,
    this.showControls = false,
    this.hintText,
    this.accentColor = const Color(0xFF58CC02),
    this.onReaction,
  });

  final MascotState initialState;
  final double mascotSize;
  final double height;
  final bool fireMode;
  final bool showSpeechBubble;
  final bool showControls;
  final String? hintText;
  final Color accentColor;
  final ValueChanged<MascotState>? onReaction;

  @override
  State<InteractiveMascotStage> createState() => _InteractiveMascotStageState();
}

class _InteractiveMascotStageState extends State<InteractiveMascotStage> {
  late MascotState _currentState;
  late bool _fireMode;
  int _reactionIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _dragStarted = false;
  String? _customQuote;

  static const double _maxOffset = 34.0;

  @override
  void initState() {
    super.initState();
    _fireMode = widget.fireMode;
    _currentState = _fireMode && widget.initialState == MascotState.idle
        ? MascotState.fireLoop
        : widget.initialState;
  }

  @override
  void didUpdateWidget(covariant InteractiveMascotStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fireMode != widget.fireMode) {
      _fireMode = widget.fireMode;
      if (!_isDragging) {
        _currentState = _restingState;
      }
    } else if (oldWidget.initialState != widget.initialState && !_isDragging) {
      _currentState = widget.initialState;
      _customQuote = null;
    }
  }

  MascotState get _restingState =>
      _fireMode ? MascotState.fireLoop : widget.initialState;

  void _triggerState(MascotState state, {String? quote}) {
    setState(() {
      _currentState = state;
      _customQuote = quote;
    });
    widget.onReaction?.call(state);
  }

  void _handleTap() {
    final reactions = MascotAssets.clickReactions;
    final next = reactions[_reactionIndex % reactions.length];
    _reactionIndex++;
    _triggerState(next);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _triggerState(MascotState.holdGrab);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    _triggerState(_restingState);
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStarted = true;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final nextOffset = Offset(
      (_dragOffset.dx + details.delta.dx).clamp(-_maxOffset, _maxOffset),
      (_dragOffset.dy + details.delta.dy).clamp(-_maxOffset, _maxOffset),
    );

    // Verifica colisão imediata ao atingir os limites do palco.
    MascotState? hitState;
    if (nextOffset.dx >= _maxOffset && details.delta.dx > 2.5) {
      hitState = MascotState.wallHitRight;
    } else if (nextOffset.dx <= -_maxOffset && details.delta.dx < -2.5) {
      hitState = MascotState.wallHitLeft;
    } else if (nextOffset.dy <= -_maxOffset && details.delta.dy < -2.5) {
      hitState = MascotState.wallHitTop;
    } else if (nextOffset.dy >= _maxOffset && details.delta.dy > 2.5) {
      hitState = MascotState.wallHitBottom;
    }

    if (hitState != null) {
      setState(() {
        _dragOffset = nextOffset;
        _currentState = hitState!;
        _customQuote = null;
      });
      widget.onReaction?.call(hitState);
      return;
    }

    final dx = details.delta.dx;
    final dy = details.delta.dy;
    final MascotState dragState;
    if (dx.abs() >= dy.abs()) {
      if (dx >= 0) {
        dragState = _dragStarted
            ? MascotState.dragStartRight
            : MascotState.dragMoveRight;
      } else {
        dragState = _dragStarted
            ? MascotState.dragStartLeft
            : MascotState.dragMoveLeft;
      }
    } else {
      if (dy < 0) {
        dragState = _dragStarted
            ? MascotState.dragStartUp
            : MascotState.dragMoveUp;
      } else {
        dragState = _dragStarted
            ? MascotState.dragStartDown
            : MascotState.dragMoveDown;
      }
    }

    setState(() {
      _dragOffset = nextOffset;
      _currentState = dragState;
      _dragStarted = false;
      _customQuote = null;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    final vx = details.velocity.pixelsPerSecond.dx;
    final vy = details.velocity.pixelsPerSecond.dy;

    MascotState releaseState = _restingState;
    if (math.max(vx.abs(), vy.abs()) > 260) {
      if (vx.abs() >= vy.abs()) {
        releaseState = vx > 0
            ? MascotState.wallHitRight
            : MascotState.wallHitLeft;
      } else {
        releaseState = vy < 0
            ? MascotState.wallHitTop
            : MascotState.wallHitBottom;
      }
      widget.onReaction?.call(releaseState);
    }

    setState(() {
      _isDragging = false;
      _dragStarted = false;
      _dragOffset = Offset.zero;
      _currentState = releaseState;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final spec = MascotAssets.specFor(_currentState);
    final quote = _customQuote ?? spec.defaultQuote;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  widget.accentColor.withValues(alpha: 0.14),
                  const Color(0xFF14212C),
                ]
              : [
                  widget.accentColor.withValues(alpha: 0.08),
                  Colors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: isDark ? 0.3 : 0.22),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.height),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleTap,
                  onLongPressStart: _handleLongPressStart,
                  onLongPressEnd: _handleLongPressEnd,
                  onPanStart: _handlePanStart,
                  onPanUpdate: _handlePanUpdate,
                  onPanEnd: _handlePanEnd,
                  child: AnimatedContainer(
                    duration: _isDragging
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    width: widget.mascotSize + 36,
                    height: widget.mascotSize + 24,
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: _dragOffset,
                      child: MascotSprite(
                        state: _currentState,
                        size: widget.mascotSize,
                        glowColor: _fireMode
                            ? Colors.deepOrangeAccent
                            : widget.accentColor,
                        onCompleted: () {
                          if (!mounted || _isDragging) return;
                          if (!MascotAssets.specFor(_currentState).loop) {
                            setState(() {
                              _currentState = _restingState;
                              _customQuote = null;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showSpeechBubble) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            spec.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: widget.accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          quote,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        widget.hintText ??
                            'Toque, segure ou arraste o bode para interagir',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.showControls) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  avatar: Icon(
                    _fireMode
                        ? Icons.local_fire_department_rounded
                        : Icons.whatshot_outlined,
                    size: 16,
                    color: _fireMode ? Colors.deepOrange : widget.accentColor,
                  ),
                  label: Text(
                    _fireMode ? 'Modo Chama Ativo' : 'Ativar Modo Chama',
                  ),
                  onPressed: () {
                    setState(() {
                      _fireMode = !_fireMode;
                      _currentState = _restingState;
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Foco Intenso'),
                  onPressed: () => _triggerState(MascotState.intense),
                ),
                ActionChip(
                  avatar: const Icon(Icons.celebration_rounded, size: 16),
                  label: const Text('Comemorar'),
                  onPressed: () => _triggerState(MascotState.celebrate),
                ),
                ActionChip(
                  avatar: const Icon(Icons.favorite_rounded, size: 16),
                  label: const Text('Carinho'),
                  onPressed: () => _triggerState(MascotState.clickHeart),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Estúdio interativo do mascote que carrega sob demanda os catálogos oficiais
/// (`catalog_24fps.json` e `catalog_interactive.json`) e permite pré-visualizar
/// todas as 23 animações, os 27 GIFs (Bode Branco 24 FPS + Interativos + Bode Verde)
/// e alternar a preferência global sem carregar todas as animações de uma só vez.
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
  bool _previewAsGif = true;
  String _selectedCategory = 'Todas';
  Future<_LoadedCatalogMeta>? _catalogFuture;

  static List<String> get _categories => [
    'Todas',
    ...MascotAssets.specs.values.map((s) => s.category).toSet(),
  ];

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalogs();
  }

  Future<_LoadedCatalogMeta> _loadCatalogs() async {
    final cache = MascotSpriteCache.instance;
    final results = await Future.wait<dynamic>([
      cache.loadJson(MascotAssets.catalog24FpsJson),
      cache.loadJson(MascotAssets.catalogInteractiveJson),
    ]);
    return _LoadedCatalogMeta(
      catalog24: results[0] is List ? results[0] as List<dynamic> : null,
      catalogInteractive: results[1] is List ? results[1] as List<dynamic> : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allSpecs = MascotAssets.specs.values.toList();
    final filteredSpecs = _selectedCategory == 'Todas'
        ? allSpecs
        : allSpecs.where((s) => s.category == _selectedCategory).toList();
    final selectedSpec = MascotAssets.specFor(_selectedState);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ValueListenableBuilder<MascotVariant>(
            valueListenable: MascotPreferenceController.variant,
            builder: (context, currentVariant, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      MascotPoseEmblem(state: _selectedState, size: 36),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Estúdio & Catálogo do Mascote Duolinfo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Alternância entre variantes e formato de preview (GIF sob demanda / Spritesheet)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        avatar: const MascotPoseEmblem(
                          overrideVariant: MascotVariant.white,
                          size: 20,
                        ),
                        label: const Text('Bode Branco (24 FPS)'),
                        selected: currentVariant == MascotVariant.white,
                        onSelected: (_) => MascotPreferenceController.setVariant(
                          MascotVariant.white,
                        ),
                      ),
                      ChoiceChip(
                        avatar: const MascotPoseEmblem(
                          overrideVariant: MascotVariant.green,
                          size: 20,
                        ),
                        label: const Text('Bode Verde (Clássico)'),
                        selected: currentVariant == MascotVariant.green,
                        onSelected: (_) => MascotPreferenceController.setVariant(
                          MascotVariant.green,
                        ),
                      ),
                      FilterChip(
                        label: Text(
                          _previewAsGif
                              ? 'Prévia: GIF Oficial'
                              : 'Prévia: Spritesheet 24 FPS',
                        ),
                        selected: _previewAsGif,
                        onSelected: (v) => setState(() => _previewAsGif = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Palco selecionado sob demanda (apenas 1 animação decodificada por vez)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF16222B)
                          : const Color(0xFFF6FAF3),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF58CC02).withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        _previewAsGif
                            ? MascotGifBadge(
                                state: _selectedState,
                                size: 96,
                              )
                            : MascotSprite(
                                state: _selectedState,
                                size: 96,
                                useMaster24FpsAtlas: true,
                              ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedSpec.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedSpec.defaultQuote,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              FutureBuilder<_LoadedCatalogMeta>(
                                future: _catalogFuture,
                                builder: (context, snapshot) {
                                  final meta = snapshot.data;
                                  final totalInteractive =
                                      meta?.catalogInteractive?.length ?? 19;
                                  final totalCore =
                                      meta?.catalog24?.length ?? 4;
                                  final gifUsed = MascotAssets.gifFor(
                                    _selectedState,
                                    variant: currentVariant,
                                  ).split('/').last;
                                  return Text(
                                    'Catálogo: $totalCore principais 24 FPS + $totalInteractive interativas • '
                                    '${selectedSpec.frameCount} quadros (${selectedSpec.fps} FPS) • $gifUsed',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _categories.map((cat) {
                      return ChoiceChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  // Grade lazy com poses estáticas (não decodifica os 27 GIFs simultaneamente)
                  Expanded(
                    child: GridView.builder(
                      itemCount: filteredSpecs.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 150,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.05,
                          ),
                      itemBuilder: (context, index) {
                        final spec = filteredSpecs[index];
                        final selected = spec.state == _selectedState;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () =>
                              setState(() => _selectedState = spec.state),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(
                                      0xFF58CC02,
                                    ).withValues(alpha: 0.14)
                                  : theme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF58CC02)
                                    : theme.dividerColor.withValues(
                                        alpha: 0.4,
                                      ),
                                width: selected ? 1.8 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                MascotPoseEmblem(state: spec.state, size: 52),
                                const SizedBox(height: 6),
                                Text(
                                  spec.title,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: selected
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoadedCatalogMeta {
  const _LoadedCatalogMeta({
    this.catalog24,
    this.catalogInteractive,
  });

  final List<dynamic>? catalog24;
  final List<dynamic>? catalogInteractive;
}
