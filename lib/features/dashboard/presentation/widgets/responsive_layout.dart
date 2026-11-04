import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const double compactLayoutBreakpoint = 600;
const double desktopBreakpoint = 1024;

bool isCompactLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < compactLayoutBreakpoint;

bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= desktopBreakpoint;

EdgeInsets responsivePagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < compactLayoutBreakpoint) {
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 16);
  } else if (width < desktopBreakpoint) {
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
  } else {
    return const EdgeInsets.symmetric(horizontal: 32, vertical: 28);
  }
}

EdgeInsets responsiveCardPadding(BuildContext context) =>
    EdgeInsets.all(isCompactLayout(context) ? 14 : 20);

EdgeInsets responsiveBannerPadding(BuildContext context) =>
    EdgeInsets.all(isCompactLayout(context) ? 18 : 26);

double responsiveDialogWidth(
  BuildContext context, {
  required double maxWidth,
}) => (MediaQuery.sizeOf(context).width - 32).clamp(0.0, maxWidth);

class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.cards,
    this.columns = 2,
    this.desktopColumns,
  });

  final List<Widget> cards;
  final int columns;
  final int? desktopColumns;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int activeCols;
        if (width < 560) {
          activeCols = 1;
        } else if (width < 900) {
          activeCols = columns;
        } else {
          activeCols = desktopColumns ?? (cards.length >= 4 ? 4 : columns);
        }

        if (activeCols == 1) {
          return Column(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                if (reduceMotion)
                  cards[index]
                else
                  cards[index]
                      .animate(delay: (index * 60).ms)
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
              ],
            ],
          );
        }

        const spacing = 14.0;
        final cardWidth =
            (width - spacing * (activeCols - 1)) / activeCols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var index = 0; index < cards.length; index++)
              SizedBox(
                width: cardWidth,
                child: reduceMotion
                    ? cards[index]
                    : cards[index]
                        .animate(delay: (index * 60).ms)
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
              ),
          ],
        );
      },
    );
  }
}

class AppHoverCard extends StatefulWidget {
  const AppHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16,
    this.accentColor,
    this.scale = 1.018,
    this.cursor = SystemMouseCursors.click,
    this.borderWidth = 1.5,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? accentColor;
  final double scale;
  final MouseCursor cursor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;

  @override
  State<AppHoverCard> createState() => _AppHoverCardState();
}

class _AppHoverCardState extends State<AppHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? widget.cursor : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered && widget.onTap != null ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                if (_isHovered && widget.onTap != null)
                  BoxShadow(
                    color: accent.withValues(alpha: isDark ? 0.35 : 0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: widget.padding != null
                ? Padding(padding: widget.padding!, child: widget.child)
                : widget.child,
          ),
        ),
      ),
    );
  }
}

class AppHoverButton extends StatefulWidget {
  const AppHoverButton({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 12,
    this.accentColor,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;

  @override
  State<AppHoverButton> createState() => _AppHoverButtonState();
}

class _AppHoverButtonState extends State<AppHoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered && widget.onTap != null ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                if (_isHovered && widget.onTap != null)
                  BoxShadow(
                    color: accent.withValues(alpha: isDark ? 0.4 : 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: widget.padding != null
                ? Padding(padding: widget.padding!, child: widget.child)
                : widget.child,
          ),
        ),
      ),
    );
  }
}
