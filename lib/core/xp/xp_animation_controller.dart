import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists earned XP from completed learning tasks so returning to the home
/// screen triggers the celebratory avatar XP ring growth & glow animation.
class XpAnimationController {
  XpAnimationController._();

  static const String _pendingXpKey = 'pending_home_xp_gain';
  static const String _pendingSourceKey = 'pending_home_xp_source';

  static final XpAnimationController instance = XpAnimationController._();
  static final ValueNotifier<int> pendingXp = ValueNotifier<int>(0);
  static final ValueNotifier<String?> pendingSource = ValueNotifier<String?>(null);

  static Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      pendingXp.value = sp.getInt(_pendingXpKey) ?? 0;
      pendingSource.value = sp.getString(_pendingSourceKey);
    } catch (_) {}
  }

  static Future<void> recordXpGain(int amount, {String? source}) async {
    if (amount <= 0) return;
    final nextTotal = pendingXp.value + amount;
    pendingXp.value = nextTotal;
    if (source != null && source.trim().isNotEmpty) {
      pendingSource.value = source.trim();
    }
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_pendingXpKey, nextTotal);
      if (pendingSource.value != null) {
        await sp.setString(_pendingSourceKey, pendingSource.value!);
      }
    } catch (_) {}
  }

  /// Atomically consumes all pending XP to play the home avatar animation.
  static Future<int> consumePendingXp() async {
    int amount = pendingXp.value;
    if (amount <= 0) {
      try {
        final sp = await SharedPreferences.getInstance();
        amount = sp.getInt(_pendingXpKey) ?? 0;
      } catch (_) {}
    }
    if (amount <= 0) return 0;

    pendingXp.value = 0;
    pendingSource.value = null;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_pendingXpKey);
      await sp.remove(_pendingSourceKey);
    } catch (_) {}
    return amount;
  }

  @visibleForTesting
  static void resetForTest() {
    pendingXp.value = 0;
    pendingSource.value = null;
  }
}
