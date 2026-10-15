import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController {
  AppThemeController._();

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);
  static const _storageKey = 'duolinfo_theme_mode';

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    mode.value = preferences.getString(_storageKey) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  static Future<void> setMode(ThemeMode value) async {
    mode.value = value;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        value == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {
      // Keep the selected theme active for the current session.
    }
  }
}
