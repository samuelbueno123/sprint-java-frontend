import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'responsive_layout.dart';

class InfoStatCard extends StatefulWidget {
  const InfoStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  State<InfoStatCard> createState() => _InfoStatCardState();
}

class _InfoStatCardState extends State<InfoStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget cardWidget = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered && widget.onTap != null
                ? widget.accentColor.withValues(alpha: 0.6)
                : (isDark ? const Color(0xFF343B49) : const Color(0xFFE2E8F0)),
            width: _isHovered && widget.onTap != null ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (_isHovered && widget.onTap != null)
              BoxShadow(
                color: widget.accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: responsiveCardPadding(context),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(isCompactLayout(context) ? 10 : 12),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: isDark ? 0.24 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.accentColor,
                    size: isCompactLayout(context) ? 24 : 28,
                  ),
                ),
                SizedBox(width: isCompactLayout(context) ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.value,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.onTap != null)
                  AnimatedSlide(
                    offset: _isHovered ? const Offset(0.15, 0) : Offset.zero,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: _isHovered
                          ? widget.accentColor
                          : (isDark ? Colors.white54 : Colors.grey.shade400),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (_isHovered && widget.onTap != null && !reduceMotion) {
      return cardWidget.animate(target: 1).scale(
        begin: const Offset(1, 1),
        end: const Offset(1.015, 1.015),
        duration: 150.ms,
        curve: Curves.easeOut,
      );
    }

    return cardWidget;
  }
}
