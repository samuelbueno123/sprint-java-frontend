import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../motion_kit.dart';
import 'mascot_assets.dart';

/// Controla preferências globais de aparência e movimento do mascote,
/// respeitando sempre a preferência de redução de movimento do sistema.
abstract final class MascotPreferenceController {
  MascotPreferenceController._();

  static const _variantKey = 'mascot_variant';
  static const _animationsKey = 'mascot_animations_enabled';

  static final ValueNotifier<MascotVariant> variant =
      ValueNotifier<MascotVariant>(MascotVariant.white);

  static final ValueNotifier<bool> animationsEnabled = ValueNotifier<bool>(
    true,
  );

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    variant.value = MascotVariant.fromId(prefs.getString(_variantKey));
    animationsEnabled.value = prefs.getBool(_animationsKey) ?? true;
  }

  static Future<void> setVariant(MascotVariant next) async {
    if (variant.value == next) return;
    variant.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_variantKey, next.id);
    } catch (_) {
      // Keeps in-memory selection even if storage is unavailable.
    }
  }

  static Future<void> setAnimationsEnabled(bool enabled) async {
    if (animationsEnabled.value == enabled) return;
    animationsEnabled.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_animationsKey, enabled);
    } catch (_) {
      // Keeps in-memory selection even if storage is unavailable.
    }
  }

  /// Retorna `true` apenas quando nem o sistema nem o usuário solicitaram redução de movimento,
  /// e não estamos executando sob `TestWidgetsFlutterBinding`.
  static bool shouldAnimate(BuildContext context) {
    if (isWidgetTestEnvironment) return false;
    final disableSystem = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableSystem) return false;
    return animationsEnabled.value;
  }
}
