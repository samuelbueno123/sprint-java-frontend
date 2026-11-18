import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/audio/system_sound_service.dart';
import '../../../../core/ui/motion_kit.dart';
import '../../../../core/xp/xp_animation_controller.dart';
import '../../../../core/xp/xp_level_progression.dart';
import 'app_user_avatar.dart';

/// Profile avatar framed by an XP progress ring that listens for queued XP
/// gains from completed learning tasks and plays a scale + golden glow +
/// XP roll-up animation upon returning to the home screen.
class AnimatedXpAvatarRing extends StatefulWidget {
  const AnimatedXpAvatarRing({
    super.key,
    required this.name,
    required this.pictureUrl,
    required this.dailyXp,
    required this.dailyGoalXp,
    this.totalXp,
    this.radius = 41,
    this.ringSize = 98,
    this.onAnimatingChanged,
    this.forceAnimateInTest = false,
  });

  final String name;
  final String? pictureUrl;
  final int dailyXp;
  final int dailyGoalXp;
  final int? totalXp;
  final double radius;
  final double ringSize;
  final ValueChanged<bool>? onAnimatingChanged;
  final bool forceAnimateInTest;

  @override
  State<AnimatedXpAvatarRing> createState() => _AnimatedXpAvatarRingState();
}

class _AnimatedXpAvatarRingState extends State<AnimatedXpAvatarRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _gainedXp = 0;
  int _fromXp = 0;
  int _toXp = 0;
  int _fromTotalXp = 0;
  int _toTotalXp = 0;
  bool _consuming = false;
  Timer? _startDelayTimer;

  @override
  void initState() {
    super.initState();
    _toXp = widget.dailyXp;
    _fromXp = widget.dailyXp;
    _toTotalXp = widget.totalXp ?? 0;
    _fromTotalXp = widget.totalXp ?? 0;
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2400),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() {
              _gainedXp = 0;
              _fromXp = _toXp;
              _fromTotalXp = _toTotalXp;
            });
            widget.onAnimatingChanged?.call(false);
          }
        });

    XpAnimationController.pendingXp.addListener(_onPendingChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleConsumeCheck();
    });
  }

  @override
  void didUpdateWidget(covariant AnimatedXpAvatarRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dailyChanged = oldWidget.dailyXp != widget.dailyXp;
    final totalChanged = oldWidget.totalXp != widget.totalXp;
    if ((dailyChanged || totalChanged) && !_controller.isAnimating) {
      _toXp = math.max(widget.dailyXp, _toXp);
      _fromXp = _toXp;
      if (widget.totalXp != null) {
        _toTotalXp = math.max(widget.totalXp!, _toTotalXp);
        _fromTotalXp = _toTotalXp;
      }
      _scheduleConsumeCheck();
    }
  }

  @override
  void dispose() {
    _startDelayTimer?.cancel();
    XpAnimationController.pendingXp.removeListener(_onPendingChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onPendingChanged() {
    if (XpAnimationController.pendingXp.value > 0) {
      _scheduleConsumeCheck();
    }
  }

  void _scheduleConsumeCheck() {
    if (!mounted || _consuming || XpAnimationController.pendingXp.value <= 0) {
      return;
    }
    _startDelayTimer?.cancel();
    if (isWidgetTestEnvironment && !widget.forceAnimateInTest) {
      unawaited(_consumeAndAnimate());
      return;
    }
    // Slight delay allows the home banner transition and streak reload to settle.
    _startDelayTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted) unawaited(_consumeAndAnimate());
    });
  }

  Future<void> _consumeAndAnimate() async {
    if (_consuming || !mounted) return;
    _consuming = true;
    try {
      final earned = await XpAnimationController.consumePendingXp();
      if (!mounted || earned <= 0) return;

      final targetXp = widget.dailyXp >= earned
          ? widget.dailyXp
          : (widget.dailyXp + earned);
      final startXp = math.max(0, targetXp - earned);

      final rawTotal = widget.totalXp ?? 0;
      final targetTotal = rawTotal >= earned ? rawTotal : (rawTotal + earned);
      final startTotal = math.max(0, targetTotal - earned);

      if (isWidgetTestEnvironment && !widget.forceAnimateInTest) {
        setState(() {
          _toXp = targetXp;
          _fromXp = targetXp;
          _toTotalXp = targetTotal;
          _fromTotalXp = targetTotal;
          _gainedXp = 0;
        });
        return;
      }

      SystemSoundService.xpGain();
      widget.onAnimatingChanged?.call(true);
      setState(() {
        _gainedXp = earned;
        _fromXp = startXp;
        _toXp = targetXp;
        _fromTotalXp = startTotal;
        _toTotalXp = targetTotal;
      });
      _controller.forward(from: 0.0);
    } finally {
      _consuming = false;
    }
  }

  double _scaleAt(double t) {
    if (t <= 0) return 1.0;
    if (t < 0.22) {
      return uiLerp(1.0, 1.18, Curves.easeOutBack.transform(t / 0.22));
    }
    if (t < 0.74) {
      final pulse = math.sin(((t - 0.22) / 0.52) * math.pi * 2) * 0.025;
      return 1.16 + pulse;
    }
    return uiLerp(1.16, 1.0, Curves.easeInOutCubic.transform((t - 0.74) / 0.26));
  }

  double _glowAt(double t) {
    if (t <= 0) return 0.0;
    if (t < 0.18) return (t / 0.18).clamp(0.0, 1.0);
    if (t < 0.76) return 1.0;
    return (1.0 - ((t - 0.76) / 0.24)).clamp(0.0, 1.0);
  }

  double _xpRollAt(double t) {
    if (t <= 0.16) return 0.0;
    if (t >= 0.72) return 1.0;
    return Curves.easeOutCubic.transform((t - 0.16) / 0.56);
  }

  double uiLerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final safeGoal = widget.dailyGoalXp > 0 ? widget.dailyGoalXp : 50;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final isActive = _gainedXp > 0 && (_controller.isAnimating || t > 0);
        final scale = isActive ? _scaleAt(t) : 1.0;
        final glow = isActive ? _glowAt(t) : 0.0;
        final roll = isActive ? _xpRollAt(t) : 1.0;

        final baseXp = isActive ? _fromXp : widget.dailyXp;
        final endXp = isActive ? _toXp : widget.dailyXp;
        final displayedXp =
            (baseXp + ((endXp - baseXp) * roll).round()).clamp(0, 9999999);

        final hasTotalXp = widget.totalXp != null;
        final baseTotal = isActive ? _fromTotalXp : (widget.totalXp ?? 0);
        final endTotal = isActive ? _toTotalXp : (widget.totalXp ?? 0);
        final displayedTotal = (baseTotal + ((endTotal - baseTotal) * roll).round())
            .clamp(0, 99999999);
        final levelInfo = hasTotalXp
            ? XpLevelProgression.fromXp(displayedTotal)
            : null;
        final progress = levelInfo != null
            ? levelInfo.progress.clamp(0.06, 1.0)
            : (displayedXp / safeGoal).clamp(0.08, 1.0);
        final badgeText = levelInfo != null
            ? 'Nível ${levelInfo.level} • ${levelInfo.currentLevelXp}/${levelInfo.xpRequiredForNextLevel} XP'
            : '$displayedXp / $safeGoal XP hoje';

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: SizedBox(
                width: widget.ringSize + 10,
                height: widget.ringSize + 10,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (glow > 0.01)
                      Container(
                        width: widget.ringSize + 6,
                        height: widget.ringSize + 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFACC15).withValues(
                                alpha: 0.72 * glow,
                              ),
                              blurRadius: 24 * glow,
                              spreadRadius: 4 * glow,
                            ),
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(
                                alpha: 0.45 * glow,
                              ),
                              blurRadius: 36 * glow,
                              spreadRadius: 6 * glow,
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: widget.ringSize,
                      height: widget.ringSize,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 4.5 + (2.0 * glow),
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    SizedBox(
                      width: widget.ringSize,
                      height: widget.ringSize,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4.5 + (2.5 * glow),
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation(
                          Color.lerp(
                            const Color(0xFFFFD000),
                            const Color(0xFFFEF08A),
                            glow * 0.6,
                          )!,
                        ),
                      ),
                    ),
                    AppUserAvatar(
                      name: widget.name,
                      pictureUrl: widget.pictureUrl,
                      radius: widget.radius,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      textColor: Colors.white,
                    ),
                    if (isActive && glow > 0.05)
                      Positioned(
                        top: -10,
                        child: Opacity(
                          opacity: glow,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFACC15), Color(0xFFF59E0B)],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '+$_gainedXp XP!',
                              style: const TextStyle(
                                color: Color(0xFF422006),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isActive && glow > 0.1
                    ? const Color(0xFFFACC15).withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive && glow > 0.1
                      ? const Color(0xFFFEF08A)
                      : Colors.white.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  shadows: isActive && glow > 0.1
                      ? [
                          const Shadow(
                            color: Color(0xFFFACC15),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
