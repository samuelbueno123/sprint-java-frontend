import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:velocity_x/velocity_x.dart';

const double compactLayoutBreakpoint = 600;
const double tabletBreakpoint = 768;
const double desktopBreakpoint = 1024;
const double largeDesktopBreakpoint = 1440;

bool isCompactLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < compactLayoutBreakpoint;

bool isMobileLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < tabletBreakpoint;

bool isTabletLayout(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= tabletBreakpoint && width < desktopBreakpoint;
}

bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= desktopBreakpoint;

bool isLargeDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= largeDesktopBreakpoint;

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

/// Staggered card grid adapted to mobile (1 col), tablet (2 cols), and desktop (3-4 cols).
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
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

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
                      .animate(delay: (index * 50).ms)
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
              ],
            ],
          );
        }

        const spacing = 14.0;
        final cardWidth = (width - spacing * (activeCols - 1)) / activeCols;

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
                          .animate(delay: (index * 50).ms)
                          .fadeIn(duration: 320.ms)
                          .slideY(
                            begin: 0.06,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),
              ),
          ],
        );
      },
    );
  }
}

/// Elevated Card with hover effect and touch microinteractions.
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

/// Interactive Button with hover microinteractions and touch accessibility.
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
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
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

/// A modern Shadcn-style Card leveraging [ShadCard] and [Vx] extensions.
class AppModernCard extends StatelessWidget {
  const AppModernCard({
    super.key,
    this.title,
    this.subtitle,
    this.leadingIcon,
    this.accentColor,
    this.trailing,
    required this.child,
    this.padding,
    this.onTap,
    this.elevation = 0,
  });

  final String? title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Color? accentColor;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = accentColor ?? theme.colorScheme.primary;

    Widget cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Row(
            children: [
              if (leadingIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(leadingIcon, size: 18, color: accent),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 14),
        ],
        child,
      ],
    );

    return ShadCard(
      padding: padding ?? const EdgeInsets.all(18),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: cardContent,
            )
          : cardContent,
    );
  }
}

/// A modern status badge powered by [ShadBadge] with consistent semantic colors.
enum AppBadgeVariant {
  primary,
  success,
  warning,
  destructive,
  secondary,
  outline,
}

class AppModernBadge extends StatelessWidget {
  const AppModernBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = AppBadgeVariant.primary,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final AppBadgeVariant variant;
  final VoidCallback? onTap;

  Color _resolveColor(BuildContext context) {
    switch (variant) {
      case AppBadgeVariant.primary:
        return const Color(0xFF3579E8);
      case AppBadgeVariant.success:
        return const Color(0xFF16A34A);
      case AppBadgeVariant.warning:
        return const Color(0xFFD97706);
      case AppBadgeVariant.destructive:
        return const Color(0xFFDC2626);
      case AppBadgeVariant.secondary:
        return const Color(0xFF7651C8);
      case AppBadgeVariant.outline:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final badgeChild = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
      ),
      child: badgeChild,
    );

    if (onTap != null) {
      badge = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: badge,
      );
    }

    return badge;
  }
}

/// Accessible touch target wrapper (minimum 48x48dp for mobile touch guidelines).
class AppTouchTarget extends StatelessWidget {
  const AppTouchTarget({
    super.key,
    required this.child,
    this.minSize = 48.0,
    this.semanticLabel,
  });

  final Widget child;
  final double minSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget target = ConstrainedBox(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      child: Center(child: child),
    );

    if (semanticLabel != null) {
      target = Semantics(label: semanticLabel, button: true, child: target);
    }

    return target;
  }
}

/// Shimmer skeleton placeholder for loading states.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242A35) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );

    if (reduceMotion) return box;
    return box
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: (isDark ? Colors.white : Colors.grey.shade300).withValues(
            alpha: 0.15,
          ),
        );
  }
}
