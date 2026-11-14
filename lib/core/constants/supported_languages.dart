import 'package:flutter/material.dart';

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
  });

  final String canonicalName;
  final String shortCode;
  final String nativeLabel;
  final Color color;
  final IconData icon;
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
      icon: Icons.castle_rounded,
    ),
    'Espanhol': LanguageVisualMeta(
      canonicalName: 'Espanhol',
      shortCode: 'ES',
      nativeLabel: 'Español',
      color: Color(0xFFEA580C),
      icon: Icons.wb_sunny_rounded,
    ),
    'Francês': LanguageVisualMeta(
      canonicalName: 'Francês',
      shortCode: 'FR',
      nativeLabel: 'Français',
      color: Color(0xFF6366F1),
      icon: Icons.menu_book_rounded,
    ),
    'Inglês': LanguageVisualMeta(
      canonicalName: 'Inglês',
      shortCode: 'EN',
      nativeLabel: 'English',
      color: Color(0xFF2563EB),
      icon: Icons.public_rounded,
    ),
    'Italiano': LanguageVisualMeta(
      canonicalName: 'Italiano',
      shortCode: 'IT',
      nativeLabel: 'Italiano',
      color: Color(0xFF16A34A),
      icon: Icons.palette_rounded,
    ),
    'Japonês': LanguageVisualMeta(
      canonicalName: 'Japonês',
      shortCode: 'JA',
      nativeLabel: '日本語',
      color: Color(0xFFE11D48),
      icon: Icons.temple_buddhist_rounded,
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

  /// Normaliza um nome de idioma para a forma canônica (um dos 6 base),
  /// ou retorna null se não pertencer ao conjunto oficial.
  static String? normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return _lookup[_stripAccentsLower(raw)];
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
