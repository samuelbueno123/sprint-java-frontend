import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../motion_kit.dart';
import 'mascot_assets.dart';

abstract final class MascotPreferenceController {
  MascotPreferenceController._();

  static const String _variantKey = 'mascot_variant';
  static const String _animationsKey = 'mascot_animations_enabled';
  static const String _fpsKey = 'mascot_fps_value';

  static final ValueNotifier<MascotVariant> variant = ValueNotifier(
    MascotVariant.white,
  );
  static final ValueNotifier<bool> animationsEnabled = ValueNotifier(true);
  static final ValueNotifier<int> targetFps = ValueNotifier(24);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawVariant = prefs.getString(_variantKey);
      variant.value = rawVariant == 'fire' || rawVariant == 'green'
          ? MascotVariant.fire
          : MascotVariant.white;
      animationsEnabled.value = prefs.getBool(_animationsKey) ?? true;
      targetFps.value = (prefs.getInt(_fpsKey) ?? 24).clamp(4, 36);
    } catch (_) {}
  }

  static Future<void> setVariant(MascotVariant next) async {
    variant.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_variantKey, next.name);
    } catch (_) {}
  }

  static Future<void> setAnimationsEnabled(bool enabled) async {
    animationsEnabled.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_animationsKey, enabled);
    } catch (_) {}
  }

  static Future<void> setTargetFps(int fps) async {
    final clamped = fps.clamp(4, 36);
    targetFps.value = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_fpsKey, clamped);
    } catch (_) {}
  }

  static bool shouldAnimate(BuildContext context) {
    if (isWidgetTestEnvironment) return false;
    if (!animationsEnabled.value) return false;
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context);
    if (disableAnimations == true) return false;
    return true;
  }
}
