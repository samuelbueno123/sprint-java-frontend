import 'package:flutter/material.dart';

/// Unified visual design system for **Admin Geral**:
/// Blue-to-purple gradients framed by metallic / materialistic gold borders.
class AdminGeralTheme {
  AdminGeralTheme._();

  static const Color bluePrimary = Color(0xFF1D4ED8);
  static const Color indigoMid = Color(0xFF4338CA);
  static const Color purplePrimary = Color(0xFF7C3AED);
  static const Color violetAccent = Color(0xFF8B5CF6);
  static const Color deepRoyal = Color(0xFF1E3A8A);

  // Materialistic brushed-gold palette
  static const Color goldHighlight = Color(0xFFFDE68A);
  static const Color goldBright = Color(0xFFFACC15);
  static const Color goldMetallic = Color(0xFFD4AF37);
  static const Color goldBronze = Color(0xFFB48811);
  static const Color goldDark = Color(0xFF8A6708);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepRoyal, indigoMid, purplePrimary],
  );

  static const LinearGradient actionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bluePrimary, purplePrimary],
  );

  static const LinearGradient goldTrimGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldHighlight, goldMetallic, goldBronze, goldBright],
  );

  static BoxDecoration heroDecoration({
    BuildContext? context,
    bool? showGoldBorder,
    double borderRadius = 22,
    double borderWidth = 1.8,
  }) {
    final showGold =
        showGoldBorder ?? (context != null ? useGoldContour(context) : false);
    return BoxDecoration(
      gradient: heroGradient,
      borderRadius: BorderRadius.circular(borderRadius),
      border: showGold
          ? Border.all(color: goldMetallic, width: borderWidth)
          : null,
      boxShadow: [
        BoxShadow(
          color: bluePrimary.withValues(alpha: 0.24),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        if (showGold)
          BoxShadow(
            color: goldBright.withValues(alpha: 0.16),
            blurRadius: 12,
            spreadRadius: 0.5,
          ),
      ],
    );
  }

  static BoxDecoration surfaceCardDecoration(
    BuildContext context, {
    bool? showGoldBorder,
    double borderRadius = 18,
    double borderWidth = 1.4,
    bool emphasized = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showGold = showGoldBorder ?? useGoldContour(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Color.alphaBlend(
                  bluePrimary.withValues(alpha: emphasized ? 0.26 : 0.16),
                  const Color(0xFF14182B),
                ),
                Color.alphaBlend(
                  purplePrimary.withValues(alpha: emphasized ? 0.26 : 0.16),
                  const Color(0xFF1A1633),
                ),
              ]
            : [
                Color.alphaBlend(
                  bluePrimary.withValues(alpha: emphasized ? 0.11 : 0.05),
                  Colors.white,
                ),
                Color.alphaBlend(
                  purplePrimary.withValues(alpha: emphasized ? 0.12 : 0.06),
                  const Color(0xFFFDFDFF),
                ),
              ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: showGold
            ? (emphasized
                ? goldMetallic
                : goldMetallic.withValues(alpha: isDark ? 0.72 : 0.65))
            : indigoMid.withValues(alpha: isDark ? 0.30 : 0.14),
        width: showGold ? borderWidth : 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: (emphasized ? indigoMid : Colors.black).withValues(
            alpha: emphasized ? 0.14 : 0.05,
          ),
          blurRadius: emphasized ? 14 : 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration badgePillDecoration({
    BuildContext? context,
    bool? showGoldBorder,
    double borderRadius = 999,
  }) {
    final showGold =
        showGoldBorder ?? (context != null ? useGoldContour(context) : false);
    return BoxDecoration(
      gradient: actionGradient,
      borderRadius: BorderRadius.circular(borderRadius),
      border: showGold
          ? Border.all(color: goldBright.withValues(alpha: 0.85), width: 1.2)
          : null,
      boxShadow: [
        BoxShadow(
          color: purplePrimary.withValues(alpha: 0.22),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static bool useGoldContour(BuildContext context) =>
      (MediaQuery.maybeSizeOf(context)?.width ?? 400) < 600;

  static ButtonStyle filledButtonStyle({
    Color? foregroundColor,
    EdgeInsetsGeometry? padding,
    double borderRadius = 12,
    bool showGoldBorder = false,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: indigoMid,
      foregroundColor: foregroundColor ?? Colors.white,
      padding: padding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: showGoldBorder
            ? const BorderSide(color: goldMetallic, width: 1.25)
            : BorderSide.none,
      ),
    );
  }
}

/// Beveled metallic gold border wrapper on mobile, clean gradient card on desktop.
class AdminGoldGradientCard extends StatelessWidget {
  const AdminGoldGradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.borderWidth = 1.6,
    this.solidHero = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double borderWidth;
  final bool solidHero;

  @override
  Widget build(BuildContext context) {
    final showGold = AdminGeralTheme.useGoldContour(context);
    final effectiveWidth = showGold ? borderWidth : 0.0;
    return Container(
      decoration: BoxDecoration(
        gradient: showGold ? AdminGeralTheme.goldTrimGradient : null,
        color: showGold ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AdminGeralTheme.indigoMid.withValues(alpha: solidHero ? 0.26 : 0.12),
            blurRadius: solidHero ? 20 : 12,
            offset: const Offset(0, 6),
          ),
          if (showGold)
            BoxShadow(
              color: AdminGeralTheme.goldMetallic.withValues(alpha: 0.18),
              blurRadius: 8,
            ),
        ],
      ),
      padding: EdgeInsets.all(effectiveWidth),
      child: Container(
        padding: padding,
        decoration: solidHero
            ? BoxDecoration(
                gradient: AdminGeralTheme.heroGradient,
                borderRadius: BorderRadius.circular(
                  (borderRadius - effectiveWidth).clamp(4.0, 40.0),
                ),
              )
            : AdminGeralTheme.surfaceCardDecoration(
                context,
                borderRadius: (borderRadius - effectiveWidth).clamp(4.0, 40.0),
                borderWidth: showGold ? 0 : 1.0,
              ),
        child: child,
      ),
    );
  }
}
