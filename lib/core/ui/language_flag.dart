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
}

/// Crisp vector country flag rendered via [CustomPaint] so flags remain sharp
/// across all platforms (Web CanvasKit, Windows, Android, iOS, macOS, Linux)
/// without depending on system emoji fonts.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({
    super.key,
    required this.code,
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

  final CountryFlagCode code;
  final double width;
  final double borderRadius;
  final bool showBorder;

  static CountryFlagCode resolveCode(String? raw) {
    final normalized = (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('ã', 'a')
        .replaceAll('ê', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ô', 'o')
        .replaceAll('ç', 'c');

    if (normalized.contains('alem') ||
        normalized == 'de' ||
        normalized == 'de-de' ||
        normalized.contains('german')) {
      return CountryFlagCode.de;
    }
    if (normalized.contains('espan') ||
        normalized == 'es' ||
        normalized == 'es-es' ||
        normalized.contains('spanish')) {
      return CountryFlagCode.es;
    }
    if (normalized.contains('franc') ||
        normalized == 'fr' ||
        normalized == 'fr-fr' ||
        normalized.contains('french')) {
      return CountryFlagCode.fr;
    }
    if (normalized.contains('ital') ||
        normalized == 'it' ||
        normalized == 'it-it') {
      return CountryFlagCode.it;
    }
    if (normalized.contains('japon') ||
        normalized == 'ja' ||
        normalized == 'jp' ||
        normalized == 'ja-jp' ||
        normalized.contains('japan')) {
      return CountryFlagCode.jp;
    }
    if (normalized.contains('portug') ||
        normalized == 'pt' ||
        normalized == 'pt-br' ||
        normalized == 'br' ||
        normalized.contains('brasil') ||
        normalized.contains('brazil')) {
      return CountryFlagCode.br;
    }
    return CountryFlagCode.us;
  }

  @override
  Widget build(BuildContext context) {
    final height = width * 0.68;
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
        child: CustomPaint(
          size: Size(width, height),
          painter: _CountryFlagPainter(code),
        ),
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
        // Subtle crest silhouette on left band
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
    }
  }

  @override
  bool shouldRepaint(covariant _CountryFlagPainter oldDelegate) =>
      oldDelegate.code != code;
}
