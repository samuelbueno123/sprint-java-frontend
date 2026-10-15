import 'package:flutter/material.dart';

const double compactLayoutBreakpoint = 600;

bool isCompactLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < compactLayoutBreakpoint;

EdgeInsets responsivePagePadding(BuildContext context) =>
    EdgeInsets.all(isCompactLayout(context) ? 16 : 24);

EdgeInsets responsiveCardPadding(BuildContext context) =>
    EdgeInsets.all(isCompactLayout(context) ? 16 : 20);

EdgeInsets responsiveBannerPadding(BuildContext context) =>
    EdgeInsets.all(isCompactLayout(context) ? 18 : 24);

double responsiveDialogWidth(
  BuildContext context, {
  required double maxWidth,
}) => (MediaQuery.sizeOf(context).width - 32).clamp(0.0, maxWidth);

class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({super.key, required this.cards, this.columns = 2});

  final List<Widget> cards;
  final int columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560) {
        return Column(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              cards[index],
            ],
          ],
        );
      }
      const spacing = 12.0;
      final cardWidth =
          (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final card in cards) SizedBox(width: cardWidth, child: card),
        ],
      );
    },
  );
}
