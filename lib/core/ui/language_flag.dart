import 'package:flutter/material.dart';

/// Supported country flag identifiers mapped from language names or UI codes.
enum CountryFlagCode {
  de, // Alemão -> Alemanha
  es, // Espanhol -> Espanha
  fr, // Francês -> França
  us, // Inglês -> Estados Unidos
  it, // Italiano -> Itália
  jp, // Japonês -> Japão
  br, // Português -> Brasil
  pt, // Português Europeu -> Portugal
  kr, // Coreano -> Coreia do Sul
  cn, // Chinês / Mandarim -> China
  ru, // Russo -> Rússia
  gb, // Inglês Britânico -> Reino Unido
  ar, // Espanhol (Argentina) -> Argentina
  mx, // Espanhol (México) -> México
  globe, // Fallback internacional
}

class CatalogFlagPreset {
  const CatalogFlagPreset(this.code, this.label);

  final String code;
  final String label;
}

const List<CatalogFlagPreset> kCatalogFlagPresets = <CatalogFlagPreset>[
  CatalogFlagPreset('br', 'Brasil (BR)'),
  CatalogFlagPreset('pt', 'Portugal (PT)'),
  CatalogFlagPreset('us', 'EUA (US)'),
  CatalogFlagPreset('gb', 'Reino Unido (GB)'),
  CatalogFlagPreset('es', 'Espanha (ES)'),
  CatalogFlagPreset('mx', 'México (MX)'),
  CatalogFlagPreset('ar', 'Argentina (AR)'),
  CatalogFlagPreset('fr', 'França (FR)'),
  CatalogFlagPreset('de', 'Alemanha (DE)'),
  CatalogFlagPreset('it', 'Itália (IT)'),
  CatalogFlagPreset('jp', 'Japão (JP)'),
  CatalogFlagPreset('kr', 'Coreia (KR)'),
  CatalogFlagPreset('cn', 'China (CN)'),
  CatalogFlagPreset('ru', 'Rússia (RU)'),
  CatalogFlagPreset('globe', 'Global'),
];

/// Crisp vector country flag rendered via [CustomPaint] (plus optional manual URL/emoji)
/// so flags remain sharp across Web, Desktop, and Mobile.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({
    super.key,
    required this.code,
    this.customEmojiOrText,
    this.customUrl,
    this.width = 24,
    this.borderRadius = 4,
    this.showBorder = true,
  });

  factory LanguageFlag.forLanguage(
    String? languageOrCode, {
    Key? key,
    double width = 24,
    double borderRadius = 4,
    bool showBorder = true,
  }) {
    return LanguageFlag(
      key: key,
      code: resolveCode(languageOrCode),
      width: width,
      borderRadius: borderRadius,
      showBorder: showBorder,
    );
  }

  /// Resolves flag automatically by language name OR respects manual code/URL set by Admin.
  factory LanguageFlag.fromMetadata({
    Key? key,
    String? language,
    String? flagMode,
    String? flagCode,
    String? flagUrl,
    double width = 24,
    double borderRadius = 4,
    bool showBorder = true,
  }) {
    final trimmedUrl = (flagUrl ?? '').trim();
    final lowerUrl = trimmedUrl.toLowerCase();
    final hasValidUrl =
        lowerUrl.startsWith('https://') || lowerUrl.startsWith('http://');

    final trimmedCode = (flagCode ?? '').trim();
    final exactPreset = tryResolvePresetCode(trimmedCode);
    final isManual = flagMode?.trim().toUpperCase() == 'MANUAL';

    final resolvedCode = isManual
        ? (exactPreset ??
              (trimmedCode.isNotEmpty
                  ? CountryFlagCode.globe
                  : resolveCode(language)))
        : (exactPreset ?? resolveCode(language));

    final customLabel = (exactPreset == null && trimmedCode.isNotEmpty)
        ? trimmedCode
        : null;

    return LanguageFlag(
      key: key,
      code: resolvedCode,
      customEmojiOrText: customLabel,
      customUrl: isManual && hasValidUrl ? trimmedUrl : (hasValidUrl ? trimmedUrl : null),
      width: width,
      borderRadius: borderRadius,
      showBorder: showBorder,
    );
  }

  final CountryFlagCode code;
  final String? customEmojiOrText;
  final String? customUrl;
  final double width;
  final double borderRadius;
  final bool showBorder;

  static String _normalizeRaw(String? raw) {
    return (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('ã', 'a')
        .replaceAll('á', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ê', 'e')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }

  static CountryFlagCode? tryResolvePresetCode(String? raw) {
    switch (_normalizeRaw(raw)) {
      case 'de':
      case 'de-de':
        return CountryFlagCode.de;
      case 'es':
      case 'es-es':
        return CountryFlagCode.es;
      case 'fr':
      case 'fr-fr':
        return CountryFlagCode.fr;
      case 'en':
      case 'us':
      case 'en-us':
        return CountryFlagCode.us;
      case 'gb':
      case 'uk':
      case 'en-gb':
        return CountryFlagCode.gb;
      case 'it':
      case 'it-it':
        return CountryFlagCode.it;
      case 'ja':
      case 'jp':
      case 'ja-jp':
        return CountryFlagCode.jp;
      case 'br':
      case 'pt-br':
        return CountryFlagCode.br;
      case 'pt':
      case 'pt-pt':
        return CountryFlagCode.pt;
      case 'ko':
      case 'kr':
      case 'ko-kr':
        return CountryFlagCode.kr;
      case 'zh':
      case 'cn':
      case 'zh-cn':
        return CountryFlagCode.cn;
      case 'ru':
      case 'ru-ru':
        return CountryFlagCode.ru;
      case 'ar':
      case 'es-ar':
        return CountryFlagCode.ar;
      case 'mx':
      case 'es-mx':
        return CountryFlagCode.mx;
      case 'globe':
        return CountryFlagCode.globe;
      default:
        return null;
    }
  }

  static CountryFlagCode resolveCode(String? raw) {
    final normalized = _normalizeRaw(raw);
    final exact = tryResolvePresetCode(normalized);
    if (exact != null) return exact;

    if (normalized.contains('alem') ||
        normalized.contains('german') ||
        normalized.contains('deutsch')) {
      return CountryFlagCode.de;
    }
    if (normalized.contains('mexic')) {
      return CountryFlagCode.mx;
    }
    if (normalized.contains('argent')) {
      return CountryFlagCode.ar;
    }
    if (normalized.contains('espan') || normalized.contains('spanish')) {
      return CountryFlagCode.es;
    }
    if (normalized.contains('franc') || normalized.contains('french')) {
      return CountryFlagCode.fr;
    }
    if (normalized.contains('britan') || normalized.contains('reino unido')) {
      return CountryFlagCode.gb;
    }
    if (normalized.contains('ital')) {
      return CountryFlagCode.it;
    }
    if (normalized.contains('japon') ||
        normalized.contains('japan') ||
        normalized.contains('nihon')) {
      return CountryFlagCode.jp;
    }
    if (normalized.contains('corean') ||
        normalized.contains('korean') ||
        normalized.contains('hangul')) {
      return CountryFlagCode.kr;
    }
    if (normalized.contains('chines') ||
        normalized.contains('mandar') ||
        normalized.contains('chinese')) {
      return CountryFlagCode.cn;
    }
    if (normalized.contains('russ')) {
      return CountryFlagCode.ru;
    }
    if (normalized.contains('portugal')) {
      return CountryFlagCode.pt;
    }
    if (normalized.contains('portug') ||
        normalized.contains('brasil') ||
        normalized.contains('brazil')) {
      return CountryFlagCode.br;
    }
    if (normalized.contains('ingle') || normalized.contains('english')) {
      return CountryFlagCode.us;
    }
    if (normalized.isEmpty) {
      return CountryFlagCode.us;
    }
    return CountryFlagCode.globe;
  }

  static String codeString(CountryFlagCode code) => code.name;

  @override
  Widget build(BuildContext context) {
    final height = width * 0.68;

    Widget content;
    if (customUrl != null && customUrl!.isNotEmpty) {
      content = Image.network(
        customUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CustomPaint(
          size: Size(width, height),
          painter: _CountryFlagPainter(code),
        ),
      );
    } else if (customEmojiOrText != null && customEmojiOrText!.isNotEmpty) {
      content = Container(
        width: width,
        height: height,
        color: const Color(0xFFEEF2FF),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            customEmojiOrText!,
            style: TextStyle(
              fontSize: height * 0.72,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E3A8A),
            ),
          ),
        ),
      );
    } else {
      content = CustomPaint(
        size: Size(width, height),
        painter: _CountryFlagPainter(code),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                width: 0.7,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          (borderRadius - 0.6).clamp(1.0, 20.0),
        ),
        child: content,
      ),
    );
  }
}

class _CountryFlagPainter extends CustomPainter {
  const _CountryFlagPainter(this.code);

  final CountryFlagCode code;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    switch (code) {
      case CountryFlagCode.de:
        paint.color = const Color(0xFF111827);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 3), paint);
        paint.color = const Color(0xFFDD0000);
        canvas.drawRect(Rect.fromLTWH(0, h / 3, w, h / 3), paint);
        paint.color = const Color(0xFFFFCE00);
        canvas.drawRect(Rect.fromLTWH(0, (2 * h) / 3, w, h / 3 + 0.5), paint);

      case CountryFlagCode.es:
        paint.color = const Color(0xFFAA151B);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.25), paint);
        canvas.drawRect(Rect.fromLTWH(0, h * 0.75, w, h * 0.25 + 0.5), paint);
        paint.color = const Color(0xFFF1BF00);
        canvas.drawRect(Rect.fromLTWH(0, h * 0.25, w, h * 0.50), paint);
        paint.color = const Color(0xFF991B1B);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.22, h * 0.36, w * 0.12, h * 0.28),
            Radius.circular(w * 0.04),
          ),
          paint,
        );

      case CountryFlagCode.fr:
        paint.color = const Color(0xFF0055A4);
        canvas.drawRect(Rect.fromLTWH(0, 0, w / 3, h), paint);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(w / 3, 0, w / 3, h), paint);
        paint.color = const Color(0xFFEF4135);
        canvas.drawRect(Rect.fromLTWH((2 * w) / 3, 0, w / 3 + 0.5, h), paint);

      case CountryFlagCode.it:
        paint.color = const Color(0xFF009246);
        canvas.drawRect(Rect.fromLTWH(0, 0, w / 3, h), paint);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(w / 3, 0, w / 3, h), paint);
        paint.color = const Color(0xFFCE2B37);
        canvas.drawRect(Rect.fromLTWH((2 * w) / 3, 0, w / 3 + 0.5, h), paint);

      case CountryFlagCode.jp:
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
        paint.color = const Color(0xFFBC002D);
        canvas.drawCircle(Offset(w / 2, h / 2), h * 0.30, paint);

      case CountryFlagCode.br:
        paint.color = const Color(0xFF009C3B);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
        paint.color = const Color(0xFFFFDF00);
        final diamond = Path()
          ..moveTo(w / 2, h * 0.14)
          ..lineTo(w * 0.86, h / 2)
          ..lineTo(w / 2, h * 0.86)
          ..lineTo(w * 0.14, h / 2)
          ..close();
        canvas.drawPath(diamond, paint);
        paint.color = const Color(0xFF002776);
        canvas.drawCircle(Offset(w / 2, h / 2), h * 0.21, paint);
        paint.color = Colors.white;
        paint.strokeWidth = h * 0.055;
        paint.style = PaintingStyle.stroke;
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(w * 0.48, h * 0.56),
            width: h * 0.40,
            height: h * 0.24,
          ),
          -2.6,
          1.9,
          false,
          paint,
        );

      case CountryFlagCode.pt:
        paint.color = const Color(0xFF046A38);
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.4, h), paint);
        paint.color = const Color(0xFFDA291C);
        canvas.drawRect(Rect.fromLTWH(w * 0.4, 0, w * 0.6 + 0.5, h), paint);
        paint.color = const Color(0xFFFFE900);
        canvas.drawCircle(Offset(w * 0.4, h / 2), h * 0.22, paint);
        paint.color = Colors.white;
        canvas.drawCircle(Offset(w * 0.4, h / 2), h * 0.12, paint);

      case CountryFlagCode.kr:
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
        final r = h * 0.26;
        final center = Offset(w / 2, h / 2);
        paint.color = const Color(0xFFCD2E3A);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          3.14159,
          3.14159,
          true,
          paint,
        );
        paint.color = const Color(0xFF0047A0);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          0,
          3.14159,
          true,
          paint,
        );
        paint.color = const Color(0xFF111827);
        paint.strokeWidth = h * 0.07;
        canvas.drawLine(
          Offset(w * 0.16, h * 0.22),
          Offset(w * 0.28, h * 0.34),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.72, h * 0.34),
          Offset(w * 0.84, h * 0.22),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.16, h * 0.78),
          Offset(w * 0.28, h * 0.66),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.72, h * 0.66),
          Offset(w * 0.84, h * 0.78),
          paint,
        );

      case CountryFlagCode.cn:
        paint.color = const Color(0xFFDE2910);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
        paint.color = const Color(0xFFFFDE00);
        canvas.drawCircle(Offset(w * 0.22, h * 0.30), h * 0.14, paint);
        canvas.drawCircle(Offset(w * 0.40, h * 0.18), h * 0.05, paint);
        canvas.drawCircle(Offset(w * 0.46, h * 0.28), h * 0.05, paint);
        canvas.drawCircle(Offset(w * 0.46, h * 0.42), h * 0.05, paint);
        canvas.drawCircle(Offset(w * 0.40, h * 0.52), h * 0.05, paint);

      case CountryFlagCode.ru:
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 3), paint);
        paint.color = const Color(0xFF0039A6);
        canvas.drawRect(Rect.fromLTWH(0, h / 3, w, h / 3), paint);
        paint.color = const Color(0xFFD52B1E);
        canvas.drawRect(Rect.fromLTWH(0, (2 * h) / 3, w, h / 3 + 0.5), paint);

      case CountryFlagCode.gb:
        paint.color = const Color(0xFF012169);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
        paint.color = Colors.white;
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = h * 0.22;
        canvas.drawLine(Offset.zero, Offset(w, h), paint);
        canvas.drawLine(Offset(0, h), Offset(w, 0), paint);
        paint.color = const Color(0xFFC8102E);
        paint.strokeWidth = h * 0.10;
        canvas.drawLine(Offset.zero, Offset(w, h), paint);
        canvas.drawLine(Offset(0, h), Offset(w, 0), paint);
        paint.style = PaintingStyle.fill;
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(w * 0.38, 0, w * 0.24, h), paint);
        canvas.drawRect(Rect.fromLTWH(0, h * 0.35, w, h * 0.30), paint);
        paint.color = const Color(0xFFC8102E);
        canvas.drawRect(Rect.fromLTWH(w * 0.43, 0, w * 0.14, h), paint);
        canvas.drawRect(Rect.fromLTWH(0, h * 0.41, w, h * 0.18), paint);

      case CountryFlagCode.ar:
        paint.color = const Color(0xFF74ACDF);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 3), paint);
        canvas.drawRect(Rect.fromLTWH(0, (2 * h) / 3, w, h / 3 + 0.5), paint);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, h / 3, w, h / 3), paint);
        paint.color = const Color(0xFFF6B40E);
        canvas.drawCircle(Offset(w / 2, h / 2), h * 0.12, paint);

      case CountryFlagCode.mx:
        paint.color = const Color(0xFF006847);
        canvas.drawRect(Rect.fromLTWH(0, 0, w / 3, h), paint);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(w / 3, 0, w / 3, h), paint);
        paint.color = const Color(0xFFCE1126);
        canvas.drawRect(Rect.fromLTWH((2 * w) / 3, 0, w / 3 + 0.5, h), paint);
        paint.color = const Color(0xFF8B5A2B);
        canvas.drawCircle(Offset(w / 2, h / 2), h * 0.13, paint);

      case CountryFlagCode.us:
        const stripeCount = 7;
        final stripeH = h / stripeCount;
        for (var i = 0; i < stripeCount; i++) {
          paint.color = i.isEven ? const Color(0xFFB22234) : Colors.white;
          canvas.drawRect(
            Rect.fromLTWH(0, i * stripeH, w, stripeH + 0.4),
            paint,
          );
        }
        final cantonW = w * 0.44;
        final cantonH = h * (4 / 7);
        paint.color = const Color(0xFF3C3B6E);
        canvas.drawRect(Rect.fromLTWH(0, 0, cantonW, cantonH), paint);
        paint.color = Colors.white;
        final dotR = (w * 0.025).clamp(0.8, 2.0);
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 4; col++) {
            final cx = cantonW * (0.16 + col * 0.22);
            final cy = cantonH * (0.24 + row * 0.26);
            canvas.drawCircle(Offset(cx, cy), dotR, paint);
          }
        }

      case CountryFlagCode.globe:
        paint.color = const Color(0xFFE0E7FF);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
        paint.color = const Color(0xFF4F46E5);
        canvas.drawCircle(Offset(w / 2, h / 2), h * 0.36, paint);
        paint.color = Colors.white;
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = h * 0.07;
        canvas.drawCircle(Offset(w / 2, h / 2), h * 0.22, paint);
        canvas.drawLine(
          Offset(w / 2 - h * 0.34, h / 2),
          Offset(w / 2 + h * 0.34, h / 2),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CountryFlagPainter oldDelegate) =>
      oldDelegate.code != code;
}
