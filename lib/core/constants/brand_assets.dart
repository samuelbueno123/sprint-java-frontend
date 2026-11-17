import 'package:flutter/material.dart';

/// Official brand image assets provided in assets/ICONE.jpg and assets/BANNER.jpg.
class BrandAssets {
  BrandAssets._();

  static const String iconPath = 'assets/ICONE.jpg';
  static const String bannerPath = 'assets/BANNER.jpg';
}

class AppBrandIcon extends StatelessWidget {
  const AppBrandIcon({
    super.key,
    this.size = 40,
    this.borderRadius,
    this.padding = 4,
    this.borderColor,
    this.shadows,
  });

  final double size;
  final double? borderRadius;
  final double padding;
  final Color? borderColor;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.24);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? const Color(0xFFDDE3F2),
          width: 1.2,
        ),
        boxShadow:
            shadows ??
            [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((radius - 2).clamp(4.0, 40.0)),
        child: Image.asset(
          BrandAssets.iconPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => const Icon(
            Icons.school_rounded,
            color: Color(0xFF4F46E5),
          ),
        ),
      ),
    );
  }
}

class AppBrandBanner extends StatelessWidget {
  const AppBrandBanner({
    super.key,
    this.height = 78,
    this.maxWidth = 340,
    this.borderRadius = 18,
    this.borderColor,
  });

  final double height;
  final double maxWidth;
  final double borderRadius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: height),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor ?? const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF312E81).withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular((borderRadius - 4).clamp(6.0, 32.0)),
          child: Image.asset(
            BrandAssets.bannerPath,
            height: height - 12,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => const Center(
              child: Text(
                'Duolinfo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
