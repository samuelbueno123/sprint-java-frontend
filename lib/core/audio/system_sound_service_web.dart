import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'system_sound_service.dart';

web.AudioContext? _sharedAudioContext;
final Map<SystemSfxType, DateTime> _lastPlayedAt = {};

web.AudioContext? _ensureAudioContext() {
  try {
    _sharedAudioContext ??= web.AudioContext();
    if (_sharedAudioContext!.state == 'suspended') {
      _sharedAudioContext!.resume();
    }
    return _sharedAudioContext;
  } catch (_) {
    return null;
  }
}

void playPlatformSound(SystemSfxType type) {
  final now = DateTime.now();
  final prev = _lastPlayedAt[type];
  if (prev != null && now.difference(prev).inMilliseconds < 40) {
    return;
  }
  _lastPlayedAt[type] = now;

  try {
    final audio = web.HTMLAudioElement();
    audio.src = 'assets/${type.assetPath}';
    audio.volume = switch (type) {
      SystemSfxType.click || SystemSfxType.pop => 0.45,
      SystemSfxType.transition => 0.38,
      SystemSfxType.xpGain || SystemSfxType.success => 0.65,
      _ => 0.55,
    };
    audio.play().toDart.catchError((Object? _) {
      _playSynthFallback(type);
      return null;
    });
  } catch (_) {
    _playSynthFallback(type);
  }
}

void _playSynthFallback(SystemSfxType type) {
  final ctx = _ensureAudioContext();
  if (ctx == null) return;
  try {
    final now = ctx.currentTime;
    switch (type) {
      case SystemSfxType.click:
        _tone(ctx, start: now, duration: 0.055, freqStart: 780, freqEnd: 520, gain: 0.12);
      case SystemSfxType.pop:
        _tone(ctx, start: now, duration: 0.075, freqStart: 380, freqEnd: 740, gain: 0.14);
      case SystemSfxType.transition:
        _tone(ctx, start: now, duration: 0.16, freqStart: 440, freqEnd: 720, gain: 0.10);
      case SystemSfxType.notification:
        _tone(ctx, start: now, duration: 0.14, freqStart: 587.33, freqEnd: 587.33, gain: 0.14);
        _tone(ctx, start: now + 0.09, duration: 0.22, freqStart: 880, freqEnd: 880, gain: 0.14);
      case SystemSfxType.success:
        _tone(ctx, start: now, duration: 0.12, freqStart: 523.25, freqEnd: 523.25, gain: 0.14);
        _tone(ctx, start: now + 0.07, duration: 0.12, freqStart: 659.25, freqEnd: 659.25, gain: 0.14);
        _tone(ctx, start: now + 0.14, duration: 0.14, freqStart: 783.99, freqEnd: 783.99, gain: 0.14);
        _tone(ctx, start: now + 0.21, duration: 0.24, freqStart: 1046.5, freqEnd: 1046.5, gain: 0.16);
      case SystemSfxType.defeat:
        _tone(ctx, start: now, duration: 0.14, freqStart: 220, freqEnd: 205, gain: 0.16, wave: 'triangle');
        _tone(ctx, start: now + 0.12, duration: 0.16, freqStart: 174.61, freqEnd: 164, gain: 0.16, wave: 'triangle');
        _tone(ctx, start: now + 0.24, duration: 0.22, freqStart: 146.83, freqEnd: 130.8, gain: 0.16, wave: 'triangle');
      case SystemSfxType.xpGain:
        _tone(ctx, start: now, duration: 0.14, freqStart: 587.33, freqEnd: 587.33, gain: 0.12);
        _tone(ctx, start: now + 0.07, duration: 0.14, freqStart: 783.99, freqEnd: 783.99, gain: 0.13);
        _tone(ctx, start: now + 0.14, duration: 0.16, freqStart: 987.77, freqEnd: 987.77, gain: 0.14);
        _tone(ctx, start: now + 0.21, duration: 0.28, freqStart: 1567.98, freqEnd: 1567.98, gain: 0.15);
      case SystemSfxType.jump:
        _tone(ctx, start: now, duration: 0.15, freqStart: 280, freqEnd: 620, gain: 0.14);
      case SystemSfxType.splat:
        _tone(ctx, start: now, duration: 0.12, freqStart: 200, freqEnd: 95, gain: 0.18, wave: 'triangle');
      case SystemSfxType.bleat:
        _tone(ctx, start: now, duration: 0.22, freqStart: 380, freqEnd: 330, gain: 0.14, wave: 'sawtooth');
      case SystemSfxType.fire:
        _tone(ctx, start: now, duration: 0.25, freqStart: 320, freqEnd: 760, gain: 0.12, wave: 'triangle');
    }
  } catch (_) {}
}

void _tone(
  web.AudioContext ctx, {
  required double start,
  required double duration,
  required double freqStart,
  required double freqEnd,
  required double gain,
  String wave = 'sine',
}) {
  final osc = ctx.createOscillator();
  final gainNode = ctx.createGain();
  osc.type = wave;
  osc.frequency.setValueAtTime(freqStart, start);
  if (freqEnd != freqStart) {
    osc.frequency.exponentialRampToValueAtTime(freqEnd.clamp(20.0, 20000.0), start + duration);
  }
  gainNode.gain.setValueAtTime(0.0001, start);
  gainNode.gain.linearRampToValueAtTime(gain, start + 0.01);
  gainNode.gain.exponentialRampToValueAtTime(0.0001, start + duration);
  osc.connect(gainNode);
  gainNode.connect(ctx.destination);
  osc.start(start);
  osc.stop(start + duration + 0.02);
}
