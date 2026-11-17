import 'package:flutter/material.dart';

import 'brand_assets.dart';

/// Clean branded loading indicator without mascot artwork.
class AppLoader extends StatelessWidget {
  const AppLoader({
    super.key,
    required this.message,
    this.subtitle,
    this.compact = false,
    this.accentColor,
    this.showProgressBar = true,
  });

  final String message;
  final String? subtitle;
  final bool compact;
  final Color? accentColor;
  final bool showProgressBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBrandIcon(size: 56, borderColor: accent.withValues(alpha: 0.45)),
            const SizedBox(height: 16),
            SizedBox(
              width: 180,
              child: showProgressBar
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        color: accent,
                        backgroundColor: accent.withValues(alpha: 0.16),
                      ),
                    )
                  : Center(
                      child: SizedBox.square(
                        dimension: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: accent,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Clean icon illustration for empty states.
class AppEmptyIllustration extends StatelessWidget {
  const AppEmptyIllustration({
    super.key,
    this.icon = Icons.inbox_rounded,
    this.size = 76,
    this.accentColor,
  });

  final IconData icon;
  final double size;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 1.4),
      ),
      child: Icon(icon, size: size * 0.48, color: accent),
    );
  }
}

/// Clean icon illustration for error states.
class AppErrorIllustration extends StatelessWidget {
  const AppErrorIllustration({
    super.key,
    this.icon = Icons.error_outline_rounded,
    this.size = 76,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: error.withValues(alpha: 0.3), width: 1.4),
      ),
      child: Icon(icon, size: size * 0.5, color: error),
    );
  }
}

/// Clean tip / announcement banner replacing goat speech banners.
class AppInfoBanner extends StatelessWidget {
  const AppInfoBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.tips_and_updates_rounded,
    this.accentColor,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
