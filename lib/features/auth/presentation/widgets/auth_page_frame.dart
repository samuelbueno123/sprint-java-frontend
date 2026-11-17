import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/constants/brand_assets.dart';
import '../../../dashboard/presentation/widgets/responsive_layout.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.child,
    this.maxWidth = 480,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget child;
  final double maxWidth;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final keyboardOpen = viewInsets.bottom > 80;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF0B132B),
                  ]
                : const [
                    Color(0xFFF0F4FF),
                    Color(0xFFFFFFFF),
                    Color(0xFFF3F0FF),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 940;

              if (isDesktop) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 32,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left column: Interactive showcase
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              child: _buildShowcaseColumn(
                                context,
                                reduceMotion,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                          // Right column: Form card (scrolls safely on short screens)
                          Expanded(
                            flex: 5,
                            child: Center(
                              child: SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: maxWidth,
                                  ),
                                  child: _buildFormCard(context, reduceMotion),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Mobile and tablet: vertical layout with keyboard-safe scrolling
              final shortViewport = MediaQuery.sizeOf(context).height < 680;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  isCompactLayout(context) ? 14 : 24,
                  shortViewport ? 10 : (isCompactLayout(context) ? 16 : 28),
                  isCompactLayout(context) ? 14 : 24,
                  (shortViewport ? 14 : 24) + viewInsets.bottom * 0.2,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMobileHeader(
                          context,
                          reduceMotion,
                          compactHeight: shortViewport || keyboardOpen,
                        ),
                        SizedBox(height: shortViewport || keyboardOpen ? 8 : 18),
                        _buildFormCard(context, reduceMotion),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildShowcaseColumn(BuildContext context, bool reduceMotion) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final showcaseItems = [
      (
        LucideIcons.sparkles,
        'Exercícios Gerados com IA',
        'Crie e resolva atividades personalizadas para cada idioma e nível.',
        const Color(0xFF58CC02),
      ),
      (
        LucideIcons.mic,
        'Áudio e Síntese de Voz',
        'Pratique pronúncia e compreensão oral com recursos avançados de fala.',
        const Color(0xFF3579E8),
      ),
      (
        LucideIcons.trophy,
        'Gamificação e Rankings',
        'Ofensiva diária (streak), pontuação de XP, conquistas e pódios de turma.',
        const Color(0xFFE5902D),
      ),
      (
        LucideIcons.graduationCap,
        'Gestão Escolar Integrada',
        'Professores, turmas, alunos e instituições com relatórios detalhados.',
        const Color(0xFF7651C8),
      ),
    ];

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppBrandBanner(height: 82, maxWidth: 340),
        const SizedBox(height: 16),
        const AppBrandIcon(size: 64),
        const SizedBox(height: 20),
        Text(
          'Aprenda e ensine idiomas com a potência da IA',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.15,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Ambiente completo de aprendizado adaptativo para alunos e professores. Matrículas, turmas, atividades interativas e acompanhamento de progresso em tempo real.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 32),
        for (var i = 0; i < showcaseItems.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: showcaseItems[i].$4.withValues(
                      alpha: isDark ? 0.25 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    showcaseItems[i].$1,
                    color: showcaseItems[i].$4,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showcaseItems[i].$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        showcaseItems[i].$3,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    if (reduceMotion) return content;
    return content
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.05, end: 0);
  }

  Widget _buildMobileHeader(
    BuildContext context,
    bool reduceMotion, {
    bool compactHeight = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget header = Column(
      children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Voltar'),
              style: TextButton.styleFrom(foregroundColor: accentColor),
            ),
          ),
        if (compactHeight)
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppBrandBanner(height: 50, maxWidth: 210),
              SizedBox(width: 10),
              AppBrandIcon(size: 40),
            ],
          )
        else ...[
          const AppBrandBanner(height: 68, maxWidth: 280),
          const SizedBox(height: 10),
          const AppBrandIcon(size: 48),
        ],
        SizedBox(height: compactHeight ? 4 : 6),
        Text(
          'Aprenda idiomas com inteligência artificial',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 13,
          ),
        ),
      ],
    );

    if (reduceMotion) return header;
    return header
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: -0.1, end: 0);
  }

  Widget _buildFormCard(BuildContext context, bool reduceMotion) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompactLayout(context) ? 18 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onBack != null && MediaQuery.sizeOf(context).width >= 940) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Voltar'),
                  style: TextButton.styleFrom(foregroundColor: accentColor),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );

    if (reduceMotion) return card;
    return card.animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);
  }
}
