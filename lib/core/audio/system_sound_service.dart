import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'system_sound_service_stub.dart'
    if (dart.library.js_interop) 'system_sound_service_web.dart'
    as platform;

/// Catalog of system & interactive sound effects bundled under assets/sounds/.
enum SystemSfxType {
  click('assets/sounds/click.wav'),
  pop('assets/sounds/pop.wav'),
  success('assets/sounds/success.wav'),
  defeat('assets/sounds/defeat.wav'),
  transition('assets/sounds/transition.wav'),
  notification('assets/sounds/notification.wav'),
  xpGain('assets/sounds/xp_gain.wav'),
  jump('assets/sounds/jump.wav'),
  splat('assets/sounds/splat.wav'),
  bleat('assets/sounds/bleat.wav'),
  fire('assets/sounds/fire.wav');

  const SystemSfxType(this.assetPath);

  final String assetPath;
}

/// Centralized sound-effect dispatcher synchronized with the persistent
/// `sound_effects_enabled` user preference.
class SystemSoundService {
  SystemSoundService._();

  static const String prefKey = 'sound_effects_enabled';
  static final SystemSoundService instance = SystemSoundService._();
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  int playCount = 0;
  SystemSfxType? lastPlayed;

  static Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      enabled.value = sp.getBool(prefKey) ?? true;
    } catch (_) {
      enabled.value = true;
    }
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(prefKey, value);
    } catch (_) {}
  }

  static void play(SystemSfxType type) {
    if (!enabled.value) return;
    instance.playCount++;
    instance.lastPlayed = type;
    if (kIsWeb) {
      platform.playPlatformSound(type);
      return;
    }
    try {
      if (type == SystemSfxType.click || type == SystemSfxType.pop) {
        SystemSound.play(SystemSoundType.click);
      } else if (type == SystemSfxType.defeat) {
        SystemSound.play(SystemSoundType.alert);
      }
      platform.playPlatformSound(type);
    } catch (_) {}
  }

  static void click() => play(SystemSfxType.click);
  static void pop() => play(SystemSfxType.pop);
  static void success() => play(SystemSfxType.success);
  static void defeat() => play(SystemSfxType.defeat);
  static void transition() => play(SystemSfxType.transition);
  static void notification() => play(SystemSfxType.notification);
  static void xpGain() => play(SystemSfxType.xpGain);
  static void jump() => play(SystemSfxType.jump);
  static void splat() => play(SystemSfxType.splat);
  static void bleat() => play(SystemSfxType.bleat);
  static void fire() => play(SystemSfxType.fire);

  @visibleForTesting
  static void resetForTest() {
    enabled.value = true;
    instance.playCount = 0;
    instance.lastPlayed = null;
  }
}
