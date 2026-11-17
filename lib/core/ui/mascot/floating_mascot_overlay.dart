import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'mascot_assets.dart';
import 'mascot_chat_popover.dart';
import 'mascot_controller.dart';
import 'mascot_sprite_widget.dart';

class FloatingMascotOverlay extends StatefulWidget {
  const FloatingMascotOverlay({super.key, this.controller});

  final MascotController? controller;

  @override
  State<FloatingMascotOverlay> createState() => _FloatingMascotOverlayState();
}

class _FloatingMascotOverlayState extends State<FloatingMascotOverlay>
    with SingleTickerProviderStateMixin {
  static const double _edgeMargin = 8.0;

  late final Ticker _physicsTicker;
  Duration? _lastTickElapsed;

  int? _activePointer;
  DateTime? _downTime;
  DateTime? _dragStartTime;
  DateTime? _lastMoveTime;
  Offset? _downGlobalPos;
  Offset? _lastGlobalPos;
  bool _movedBeyondSlop = false;
  Offset _velocitySample = Offset.zero;
  Timer? _holdTimer;

  Size _viewportSize = Size.zero;

  MascotController get _controller =>
      widget.controller ?? MascotController.instance;

  @override
  void initState() {
    super.initState();
    _physicsTicker = createTicker(_onPhysicsTick);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant FloatingMascotOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? MascotController.instance).removeListener(
        _onControllerChanged,
      );
      _controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _physicsTicker.dispose();
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (!_controller.isSessionActive && _physicsTicker.isActive) {
      _physicsTicker.stop();
      _lastTickElapsed = null;
    }
    setState(() {});
  }

  ({double minX, double maxX, double minY, double maxY}) _boundsFor(
    Size viewport,
  ) {
    const size = MascotController.mascotDisplaySize;
    final minX = _edgeMargin;
    final maxX = math.max(_edgeMargin, viewport.width - size - _edgeMargin);
    final minY = _edgeMargin;
    final maxY = math.max(_edgeMargin, viewport.height - size - _edgeMargin);
    return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  Offset _clampPos(Offset raw, Size viewport) {
    final b = _boundsFor(viewport);
    return Offset(raw.dx.clamp(b.minX, b.maxX), raw.dy.clamp(b.minY, b.maxY));
  }

  Offset _defaultAnchor(Size viewport) {
    final b = _boundsFor(viewport);
    return _clampPos(Offset(b.maxX - 16, b.maxY - 24), viewport);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _downTime = DateTime.now();
    _dragStartTime = null;
    _lastMoveTime = _downTime;
    _downGlobalPos = event.position;
    _lastGlobalPos = event.position;
    _movedBeyondSlop = false;
    _velocitySample = Offset.zero;

    if (_physicsTicker.isActive) {
      _physicsTicker.stop();
      _lastTickElapsed = null;
    }
    _controller.setVelocity(Offset.zero);

    _holdTimer?.cancel();
    _holdTimer = Timer(MascotController.holdThreshold, () {
      if (!mounted || _activePointer != event.pointer || _movedBeyondSlop) {
        return;
      }
      _controller.beginHold();
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    final now = DateTime.now();
    final downPos = _downGlobalPos ?? event.position;
    final lastPos = _lastGlobalPos ?? event.position;
    final delta = event.position - lastPos;
    final totalDist = (event.position - downPos).distance;

    if (!_movedBeyondSlop && totalDist >= MascotController.dragSlopPx) {
      _movedBeyondSlop = true;
      _holdTimer?.cancel();
      _dragStartTime ??= now;
    }

    if (_movedBeyondSlop || _controller.isHeld) {
      final dtMs = _lastMoveTime == null
          ? 16
          : now.difference(_lastMoveTime!).inMilliseconds;
      final normalizedDelta = dtMs > 0
          ? delta * (16.666 / dtMs).clamp(0.45, 2.5)
          : delta * 0.85;
      _velocitySample = Offset(
        normalizedDelta.dx.clamp(-32.0, 32.0),
        normalizedDelta.dy.clamp(-32.0, 32.0),
      );

      final current = _controller.hasInitializedPosition
          ? _controller.position
          : _defaultAnchor(_viewportSize);
      final next = _clampPos(current + delta, _viewportSize);
      _controller.setPosition(next);

      if (delta.dx.abs() >= 0.8 || delta.dy.abs() >= 0.8) {
        final dragElapsedMs = _dragStartTime == null
            ? 300
            : now.difference(_dragStartTime!).inMilliseconds;
        final isStartPhase = dragElapsedMs < 220;
        final MascotState dragState;
        if (delta.dx.abs() >= delta.dy.abs()) {
          if (delta.dx >= 0) {
            dragState = isStartPhase
                ? MascotState.dragStartRight
                : MascotState.dragMoveRight;
          } else {
            dragState = isStartPhase
                ? MascotState.dragStartLeft
                : MascotState.dragMoveLeft;
          }
        } else {
          if (delta.dy < 0) {
            dragState = isStartPhase
                ? MascotState.dragStartUp
                : MascotState.dragMoveUp;
          } else {
            dragState = isStartPhase
                ? MascotState.dragStartDown
                : MascotState.dragMoveDown;
          }
        }
        _controller.setDragState(dragState);
      } else if (_controller.isHeld &&
          _controller.activeState != MascotState.holdGrab) {
        _controller.setDragState(MascotState.holdGrab);
      }
    }

    _lastGlobalPos = event.position;
    _lastMoveTime = now;
  }

  void _onPointerUpOrCancel(PointerEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    _holdTimer?.cancel();

    final now = DateTime.now();
    final downTime = _downTime ?? now;
    final heldDuration = now.difference(downTime);

    final isQuickTap =
        event is PointerUpEvent &&
        !_movedBeyondSlop &&
        !_controller.isHeld &&
        !_controller.isDragging &&
        heldDuration < MascotController.holdThreshold;

    if (isQuickTap) {
      _controller.handleShortTap();
      return;
    }

    final moveAgeMs = _lastMoveTime == null
        ? 999
        : now.difference(_lastMoveTime!).inMilliseconds;
    final releaseVel = moveAgeMs <= 140 ? _velocitySample : Offset.zero;

    if (releaseVel.distance > 1.5 && _movedBeyondSlop) {
      _controller.endHoldOrDrag(settleToRest: false);
      _controller.setVelocity(releaseVel);
      _lastTickElapsed = null;
      _physicsTicker.stop();
      _physicsTicker.start();
    } else {
      _controller.endHoldOrDrag(settleToRest: true);
    }
  }

  void _onPhysicsTick(Duration elapsed) {
    if (!mounted ||
        !_controller.isSessionActive ||
        _controller.isHeld ||
        _controller.isDragging) {
      _physicsTicker.stop();
      _lastTickElapsed = null;
      return;
    }

    final dtMs = _lastTickElapsed == null
        ? 16.666
        : (elapsed - _lastTickElapsed!).inMicroseconds / 1000.0;
    _lastTickElapsed = elapsed;
    final dtScale = (dtMs / 16.666).clamp(0.25, 2.0);

    final b = _boundsFor(_viewportSize);
    final pos = _controller.position;
    final vel = _controller.velocity;

    var nx = pos.dx + vel.dx * dtScale;
    var ny = pos.dy + vel.dy * dtScale;
    final damping = math.pow(0.90, dtScale).toDouble();
    var vx = vel.dx * damping;
    var vy = vel.dy * damping;

    MascotState? wallHit;
    if (nx > b.maxX) {
      nx = b.maxX;
      if (vel.dx > 4) wallHit = MascotState.wallHitRight;
      vx = -vx * 0.4;
    } else if (nx < b.minX) {
      nx = b.minX;
      if (vel.dx < -4) wallHit = MascotState.wallHitLeft;
      vx = -vx * 0.4;
    }

    if (ny > b.maxY) {
      ny = b.maxY;
      if (vel.dy > 4) wallHit ??= MascotState.wallHitBottom;
      vy = -vy * 0.4;
    } else if (ny < b.minY) {
      ny = b.minY;
      if (vel.dy < -4) wallHit ??= MascotState.wallHitTop;
      vy = -vy * 0.4;
    }

    _controller.setPosition(Offset(nx, ny), notify: false);
    _controller.setVelocity(Offset(vx, vy), notify: true);

    if (wallHit != null) {
      _controller.triggerWallHit(wallHit);
    }

    if (Offset(vx, vy).distance < 0.25) {
      _physicsTicker.stop();
      _lastTickElapsed = null;
      _controller.endHoldOrDrag(settleToRest: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isSessionActive) {
      return const SizedBox.shrink();
    }

    final viewInsetsBottom = MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 1280,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 800,
        );
        _viewportSize = viewport;

        final rawPos = _controller.hasInitializedPosition
            ? _controller.position
            : _defaultAnchor(viewport);
        if (!_controller.hasInitializedPosition) {
          _controller.initializePositionIfNeeded(rawPos);
        }
        final clampedPos = _clampPos(rawPos, viewport);
        if ((clampedPos - _controller.position).distance > 0.5 &&
            _controller.hasInitializedPosition) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _controller.setPosition(_clampPos(_controller.position, viewport));
          });
        }

        const mascotSize = MascotController.mascotDisplaySize;
        final isActivityDone = _controller.isActivityCompleted;

        // Calculate clean popover coordinates docked near the mascot inside viewport
        final popoverWidth = math.min(340.0, viewport.width - 24.0);
        final usableHeight = math.max(
          200.0,
          viewport.height - viewInsetsBottom - 24.0,
        );
        final popoverMaxHeight = math.min(
          _controller.isInActivity ? 280.0 : 410.0,
          usableHeight,
        );

        final openLeftOfMascot =
            clampedPos.dx > (viewport.width - popoverWidth - mascotSize - 24);
        final double rawPopLeft = openLeftOfMascot
            ? (clampedPos.dx - popoverWidth - 10)
            : (clampedPos.dx + mascotSize + 10);
        final double popLeft = rawPopLeft.clamp(
          12.0,
          math.max(12.0, viewport.width - popoverWidth - 12.0),
        );

        final double maxPopTop = math.max(
          12.0,
          viewport.height - viewInsetsBottom - popoverMaxHeight - 12.0,
        );
        final double rawPopTop =
            (clampedPos.dy + mascotSize / 2) - (popoverMaxHeight / 2);
        final double popTop = rawPopTop.clamp(12.0, maxPopTop);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (_controller.isChatOpen)
              Positioned(
                left: popLeft,
                top: popTop,
                child: MascotChatPopover(
                  controller: _controller,
                  maxWidth: popoverWidth,
                  maxHeight: popoverMaxHeight,
                ),
              ),
            Positioned(
              left: clampedPos.dx,
              top: clampedPos.dy,
              width: mascotSize,
              height: mascotSize,
              child: Material(
                type: MaterialType.transparency,
                child: MouseRegion(
                  cursor: _controller.isHeld || _controller.isDragging
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.click,
                  child: Tooltip(
                    message: _controller.isInActivity
                        ? 'Toque para ver dica · Segure para mover'
                        : 'Toque para falar com o Bode IA · Segure para arrastar',
                    waitDuration: const Duration(milliseconds: 650),
                    child: Listener(
                      key: const Key('floating-mascot-hit-target'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUpOrCancel,
                      onPointerCancel: _onPointerUpOrCancel,
                      child: AnimatedScale(
                        scale: _controller.isHeld ? 1.07 : 1.0,
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        child: MascotSprite(
                          state: _controller.activeState,
                          size: mascotSize,
                          maxFrames: _controller.maxFramesOverride,
                          overrideVariant: isActivityDone
                              ? MascotVariant.fire
                              : null,
                          useSpriteSheet: true,
                          onOneShotComplete: _controller.onOneShotFinished,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
