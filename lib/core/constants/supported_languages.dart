import 'package:flutter/material.dart';

import '../ui/language_flag.dart';

/// Os exatamente 6 idiomas oficiais suportados pela plataforma Duolinfo.
/// Português é usado exclusivamente como idioma da interface e explicações pedagógicas.
const List<String> kSupportedLanguages = <String>[
  'Alemão',
  'Espanhol',
  'Francês',
  'Inglês',
  'Italiano',
  'Japonês',
];

const String kDefaultSupportedLanguage = 'Inglês';

class LanguageVisualMeta {
  const LanguageVisualMeta({
    required this.canonicalName,
    required this.shortCode,
    required this.nativeLabel,
    required this.color,
    required this.icon,
    required this.flagCode,
  });

  final String canonicalName;
  final String shortCode;
  final String nativeLabel;
  final Color color;
  final IconData icon;
  final CountryFlagCode flagCode;
}

class SupportedLanguages {
  SupportedLanguages._();

  static const List<String> all = kSupportedLanguages;

  static final Map<String, String> _lookup = {
    for (final lang in kSupportedLanguages) _stripAccentsLower(lang): lang,
  };

  static const Map<String, LanguageVisualMeta> _metaByCanonical = {
    'Alemão': LanguageVisualMeta(
      canonicalName: 'Alemão',
      shortCode: 'DE',
      nativeLabel: 'Deutsch',
      color: Color(0xFFD97706),
      icon: Icons.flag_rounded,
      flagCode: CountryFlagCode.de,
    ),
    'Espanhol': LanguageVisualMeta(
      canonicalName: 'Espanhol',
      shortCode: 'ES',
      nativeLabel: 'Español',
      color: Color(0xFFEA580C),
      icon: Icons.flag_rounded,
      flagCode: CountryFlagCode.es,
    ),
    'Francês': LanguageVisualMeta(
      canonicalName: 'Francês',
      shortCode: 'FR',
      nativeLabel: 'Français',
      color: Color(0xFF6366F1),
      icon: Icons.flag_rounded,
      flagCode: CountryFlagCode.fr,
    ),
    'Inglês': LanguageVisualMeta(
      canonicalName: 'Inglês',
      shortCode: 'EN',
      nativeLabel: 'English',
      color: Color(0xFF2563EB),
      icon: Icons.flag_rounded,
      flagCode: CountryFlagCode.us,
    ),
    'Italiano': LanguageVisualMeta(
      canonicalName: 'Italiano',
      shortCode: 'IT',
      nativeLabel: 'Italiano',
      color: Color(0xFF16A34A),
      icon: Icons.flag_rounded,
      flagCode: CountryFlagCode.it,
    ),
    'Japonês': LanguageVisualMeta(
      canonicalName: 'Japonês',
      shortCode: 'JA',
      nativeLabel: '日本語',
      color: Color(0xFFE11D48),
      icon: Icons.flag_rounded,
      flagCode: CountryFlagCode.jp,
    ),
  };

  static String _stripAccentsLower(String raw) {
    final trimmed = raw.trim().toLowerCase();
    return trimmed
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');
  }

  /// Extrai nome do idioma e nível opcional de rótulos como "Inglês:Básico".
  static ({String language, String? level}) splitLanguageAndLevel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      final lang = parts.first.trim();
      final level = parts.sublist(1).join(':').trim();
      return (language: lang, level: level.isEmpty ? null : level);
    }
    return (language: trimmed, level: null);
  }

  /// Normaliza um nome de idioma para a forma canônica (um dos 6 base),
  /// ou retorna null se não pertencer ao conjunto oficial.
  static String? normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = splitLanguageAndLevel(raw).language;
    return _lookup[_stripAccentsLower(clean)];
  }

  static String levelEmoji(String? rawLevel) {
    final clean = _stripAccentsLower(rawLevel ?? '');
    if (clean.contains('avanc') ||
        clean.contains('c1') ||
        clean.contains('c2') ||
        clean.contains('fluen') ||
        clean.contains('profic')) {
      return '🚀';
    }
    if (clean.contains('interm') ||
        clean.contains('b1') ||
        clean.contains('b2')) {
      return '⚡';
    }
    if (clean.contains('basic') ||
        clean.contains('inici') ||
        clean.contains('a1') ||
        clean.contains('a2')) {
      return '🌱';
    }
    return '🎯';
  }

  static String formatLevelWithEmoji(String? rawLevel) {
    final trimmed = (rawLevel ?? '').trim();
    if (trimmed.isEmpty) return '';
    return '${levelEmoji(trimmed)} $trimmed';
  }

  static String specializationEmoji(String? raw) {
    final clean = _stripAccentsLower(raw ?? '');
    if (clean.contains('convers') || clean.contains('fala') || clean.contains('oral')) {
      return '🗣️';
    }
    if (clean.contains('gramat') || clean.contains('escrita') || clean.contains('redac')) {
      return '✍️';
    }
    if (clean.contains('negoc') || clean.contains('busin') || clean.contains('corp')) {
      return '💼';
    }
    if (clean.contains('exame') || clean.contains('prep') || clean.contains('cert')) {
      return '🎓';
    }
    if (clean.contains('leitura') || clean.contains('liter') || clean.contains('cultur')) {
      return '📚';
    }
    if (clean.contains('viag') || clean.contains('turis')) {
      return '✈️';
    }
    return '✨';
  }

  static String normalizeOrDefault(
    String? raw, [
    String fallback = kDefaultSupportedLanguage,
  ]) {
    return normalize(raw) ?? normalize(fallback) ?? kDefaultSupportedLanguage;
  }

  static bool isSupported(String? raw) => normalize(raw) != null;

  static bool matches(String? a, String? b) {
    final normA = normalize(a);
    final normB = normalize(b);
    return normA != null && normA == normB;
  }

  static String inferFromClassName(String? className) {
    if (className == null || className.trim().isEmpty) {
      return kDefaultSupportedLanguage;
    }
    final clean = _stripAccentsLower(className);
    if (clean.contains('alem')) return 'Alemão';
    if (clean.contains('espanh')) return 'Espanhol';
    if (clean.contains('franc')) return 'Francês';
    if (clean.contains('ital')) return 'Italiano';
    if (clean.contains('japon')) return 'Japonês';
    return kDefaultSupportedLanguage;
  }

  /// Filtra e preserva a ordem oficial dos 6 idiomas base caso a lista contenha
  /// entradas da API ou opções antigas.
  static List<String> sanitizeCatalogList(Iterable<String>? rawList) {
    if (rawList == null) return List<String>.from(kSupportedLanguages);
    final present = <String>{};
    for (final item in rawList) {
      final norm = normalize(item);
      if (norm != null) {
        present.add(norm);
      }
    }
    if (present.isEmpty) return List<String>.from(kSupportedLanguages);
    return kSupportedLanguages.where(present.contains).toList();
  }

  static LanguageVisualMeta metaFor(String? raw) {
    final canonical = normalizeOrDefault(raw);
    return _metaByCanonical[canonical] ??
        _metaByCanonical[kDefaultSupportedLanguage]!;
  }
}

/// Selo visual compacto e padronizado para representar um dos 6 idiomas base.
class LanguageBadgePill extends StatelessWidget {
  const LanguageBadgePill({
    super.key,
    required this.language,
    this.compact = false,
  });

  final String language;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = SupportedLanguages.metaFor(language);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: meta.color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LanguageFlag(
            code: meta.flagCode,
            width: compact ? 16 : 20,
            borderRadius: 3,
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: meta.color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              meta.shortCode,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 9 : 10,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            meta.canonicalName,
            style: TextStyle(
              color: meta.color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11.5 : 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
