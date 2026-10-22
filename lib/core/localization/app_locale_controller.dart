import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController {
  AppLocaleController._();

  static final ValueNotifier<String> languageCode = ValueNotifier<String>('pt');
  static const _storageKey = 'duolinfo_ui_language';

  static Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_storageKey);
      if (saved != null && saved.isNotEmpty) {
        languageCode.value = normalizeCode(saved);
      }
    } catch (_) {
      // Fallback to 'pt' when SharedPreferences is unavailable.
    }
  }

  static Future<void> setLanguageCode(String rawCode) async {
    final normalized = normalizeCode(rawCode);
    languageCode.value = normalized;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, normalized);
    } catch (_) {
      // Keep active for the current session.
    }
  }

  static String normalizeCode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'pt';
    }
    final lower = raw.trim().toLowerCase();
    if (lower.startsWith('en') || lower.contains('ingl') || lower.contains('english')) {
      return 'en';
    }
    if (lower.startsWith('es') || lower.contains('espan') || lower.contains('spanish')) {
      return 'es';
    }
    return 'pt';
  }

  static String displayNameForCode(String code) {
    switch (normalizeCode(code)) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      default:
        return 'Português';
    }
  }

  static String tr({
    required String pt,
    String? en,
    String? es,
  }) {
    switch (languageCode.value) {
      case 'en':
        return en ?? pt;
      case 'es':
        return es ?? pt;
      default:
        return pt;
    }
  }
}
