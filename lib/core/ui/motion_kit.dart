import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:shimmer/shimmer.dart';

/// Indica se o código está executando sob o harness automatizado de testes Flutter.
/// Usado exclusivamente para impedir que animações contínuas infinitas (shimmer/pulse)
/// travem chamadas `tester.pumpAndSettle()`.
bool get isWidgetTestEnvironment => WidgetsBinding.instance.runtimeType
    .toString()
    .contains('TestWidgetsFlutterBinding');

/// Constrói rotas com transições ricas do pacote `animations` (Material Motion).
class MotionPageRoute<T> extends PageRouteBuilder<T> {
  MotionPageRoute({
    required WidgetBuilder builder,
    this.transitionType = SharedAxisTransitionType.horizontal,
    super.settings,
    Duration duration = const Duration(milliseconds: 340),
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: const Duration(milliseconds: 260),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return SharedAxisTransition(
             animation: animation,
             secondaryAnimation: secondaryAnimation,
             transitionType: transitionType,
             child: child,
           );
         },
       );

  final SharedAxisTransitionType transitionType;
}

/// Transição fluida de troca de seções / abas usando `PageTransitionSwitcher` + `SharedAxisTransition`.
class MotionSectionSwitcher extends StatelessWidget {
  const MotionSectionSwitcher({
    super.key,
    required this.child,
    this.transitionType = SharedAxisTransitionType.scaled,
    this.duration = const Duration(milliseconds: 300),
    this.reverse = false,
  });

  final Widget child;
  final SharedAxisTransitionType transitionType;
  final Duration duration;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      duration: duration,
      reverse: reverse,
      transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
        return SharedAxisTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          transitionType: transitionType,
          fillColor: Colors.transparent,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Revelação escalonada suave com deslize, opacidade e leve escala (sem loop infinito).
class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.beginOffset = const Offset(0, 0.045),
    this.duration = const Duration(milliseconds: 360),
    this.baseDelayMs = 45,
    this.withScale = false,
  });

  final Widget child;
  final int index;
  final Offset beginOffset;
  final Duration duration;
  final int baseDelayMs;
  final bool withScale;

  @override
  Widget build(BuildContext context) {
    final cappedIndex = index.clamp(0, 8);
    final delay = Duration(milliseconds: cappedIndex * baseDelayMs);
    var effect = child
        .animate(delay: delay)
        .fadeIn(duration: duration, curve: Curves.easeOutCubic)
        .slide(
          begin: beginOffset,
          end: Offset.zero,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
    if (withScale) {
      effect = effect.scale(
        begin: const Offset(0.97, 0.97),
        end: const Offset(1, 1),
        duration: duration,
        curve: Curves.easeOutBack,
      );
    }
    return effect;
  }
}

/// Container/Card interativo com resposta tátil de hover e toque.
class InteractiveMotionCard extends StatefulWidget {
  const InteractiveMotionCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.color,
    this.borderColor,
    this.hoverBorderColor,
    this.padding,
    this.margin,
    this.elevation = 0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double elevation;

  @override
  State<InteractiveMotionCard> createState() => _InteractiveMotionCardState();
}

class _InteractiveMotionCardState extends State<InteractiveMotionCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bgColor =
        widget.color ?? theme.cardTheme.color ?? scheme.surfaceContainerLow;
    final defaultBorder =
        widget.borderColor ?? theme.dividerColor.withValues(alpha: 0.7);
    final activeBorder =
        widget.hoverBorderColor ?? scheme.primary.withValues(alpha: 0.55);

    final double targetScale = _pressed
        ? 0.985
        : (_hovered && widget.onTap != null ? 1.012 : 1.0);

    Widget content = AnimatedScale(
      scale: targetScale,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: _hovered ? activeBorder : defaultBorder,
            width: _hovered ? 1.4 : 1.0,
          ),
          boxShadow: [
            if (_hovered || widget.elevation > 0)
              BoxShadow(
                color: (_hovered ? activeBorder : Colors.black).withValues(
                  alpha: _hovered ? 0.14 : 0.06,
                ),
                blurRadius: _hovered ? 18 : 8,
                offset: Offset(0, _hovered ? 6 : 2),
              ),
          ],
        ),
        child: widget.child,
      ),
    );

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: widget.onTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              onTap: widget.onTap,
              child: content,
            )
          : content,
    );
  }
}

/// Contador numérico animado com `TweenAnimationBuilder`.
class AnimatedMetricCounter extends StatelessWidget {
  const AnimatedMetricCounter({
    super.key,
    required this.value,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 650),
  });

  final num value;
  final int decimals;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedVal, _) {
        final formatted = decimals > 0
            ? animatedVal.toStringAsFixed(decimals)
            : animatedVal.round().toString();
        return Text('$prefix$formatted$suffix', style: style);
      },
    );
  }
}

/// Barra de progresso linear estilizada e animada com `percent_indicator`.
class AnimatedLinearGauge extends StatelessWidget {
  const AnimatedLinearGauge({
    super.key,
    required this.percent,
    required this.progressColor,
    this.lineHeight = 10,
    this.backgroundColor,
    this.trailing,
  });

  final double percent;
  final Color progressColor;
  final double lineHeight;
  final Color? backgroundColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 1.0);
    return LinearPercentIndicator(
      padding: EdgeInsets.zero,
      lineHeight: lineHeight,
      percent: clamped,
      animation: !isWidgetTestEnvironment,
      animationDuration: 650,
      curve: Curves.easeOutCubic,
      barRadius: Radius.circular(lineHeight),
      progressColor: progressColor,
      backgroundColor:
          backgroundColor ??
          Theme.of(context).colorScheme.surfaceContainerHighest,
      trailing: trailing,
    );
  }
}

/// Indicador circular animado de porcentagem (`percent_indicator`) para dashboards e telemetria.
class AnimatedRadialGauge extends StatelessWidget {
  const AnimatedRadialGauge({
    super.key,
    required this.percent,
    required this.color,
    required this.centerLabel,
    this.subtitle,
    this.radius = 44,
    this.lineWidth = 8,
  });

  final double percent;
  final Color color;
  final String centerLabel;
  final String? subtitle;
  final double radius;
  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 1.0);
    return CircularPercentIndicator(
      radius: radius,
      lineWidth: lineWidth,
      percent: clamped,
      animation: !isWidgetTestEnvironment,
      animationDuration: 750,
      curve: Curves.easeOutCubic,
      circularStrokeCap: CircularStrokeCap.round,
      progressColor: color,
      backgroundColor: color.withValues(alpha: 0.14),
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            centerLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontSize: 10),
            ),
        ],
      ),
    );
  }
}

/// Esqueleto de carregamento com efeito shimmer do pacote `shimmer`.
class AppShimmerSkeleton extends StatelessWidget {
  const AppShimmerSkeleton({
    super.key,
    this.height = 96,
    this.width = double.infinity,
    this.borderRadius = 16,
  });

  final double height;
  final double width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF232936)
        : const Color(0xFFE7ECF4);
    final highlightColor = isDark
        ? const Color(0xFF343D52)
        : const Color(0xFFF6F8FC);

    final box = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );

    if (isWidgetTestEnvironment) {
      return box;
    }

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: box,
    );
  }
}

/// Grade responsiva de esqueletos shimmer para telas de loading do painel e listas.
class AppShimmerDashboardLoader extends StatelessWidget {
  const AppShimmerDashboardLoader({super.key, this.cardCount = 4});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppShimmerSkeleton(height: 112, borderRadius: 20),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final cols = isWide ? 2 : 1;
            final spacing = 14.0;
            final itemW =
                (constraints.maxWidth - (spacing * (cols - 1))) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(
                cardCount,
                (_) => AppShimmerSkeleton(
                  width: itemW,
                  height: 132,
                  borderRadius: 18,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

enum AppFeedbackTone { success, error, warning, info }

/// SnackBar / Banner flutuante animado com identidade visual polida (substitui mensagens secas).
class AppAnimatedFeedback {
  AppAnimatedFeedback._();

  static void show(
    BuildContext context, {
    required String title,
    String? message,
    AppFeedbackTone tone = AppFeedbackTone.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final Color accent;
    final IconData toneIcon;
    switch (tone) {
      case AppFeedbackTone.success:
        accent = const Color(0xFF16A34A);
        toneIcon = Icons.check_circle_rounded;
      case AppFeedbackTone.error:
        accent = const Color(0xFFDC2626);
        toneIcon = Icons.error_rounded;
      case AppFeedbackTone.warning:
        accent = const Color(0xFFD97706);
        toneIcon = Icons.warning_amber_rounded;
      case AppFeedbackTone.info:
        accent = const Color(0xFF2563EB);
        toneIcon = Icons.info_rounded;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          backgroundColor: Colors.transparent,
          duration: duration,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          content:
              Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        accent.withValues(alpha: 0.92),
                        const Color(0xFF0F172A),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            toneIcon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                              if (message != null &&
                                  message.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  message,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 12.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 240.ms)
                  .slideY(begin: 0.25, end: 0, curve: Curves.easeOutBack),
        ),
      );
  }
}
