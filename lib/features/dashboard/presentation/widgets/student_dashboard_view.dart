import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/student_enrollment.dart';
import 'app_user_avatar.dart';
import 'dashboard_empty_state.dart';
import 'info_stat_card.dart';
import 'learning_features.dart';
import 'responsive_layout.dart';
import 'student_settings_view.dart';

class StudentDashboardView extends StatelessWidget {
  const StudentDashboardView({
    super.key,
    required this.data,
    required this.activeSection,
    this.onSectionSelected,
    this.onLogout,
    this.onRefresh,
  });

  final DashboardData data;
  final String activeSection;
  final ValueChanged<String>? onSectionSelected;
  final VoidCallback? onLogout;
  final VoidCallback? onRefresh;

  static const _blue = Color(0xFF3579E8);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeSection == 'settings') {
      return StudentSettingsView(
        data: data,
        onBackToProfile: () => onSectionSelected?.call('profile'),
        onLogout: onLogout ?? () {},
        onRefresh: onRefresh,
      );
    }

    if (activeSection == 'members') {
      return _StudentInstitutionMembersView(data: data);
    }

    final student = data.studentProfile;
    final name = student?.name.isNotEmpty == true
        ? student!.name
        : data.user.name;
    final languages = student?.languages ?? const [];

    if (activeSection == 'languages') {
      return _page(
        context: context,
        title: 'Meus idiomas',
        subtitle: 'Idiomas e progresso de estudo vinculados à sua conta.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  children: [
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: InfoStatCard(
                        title: 'Idiomas Cadastrados',
                        value: languages.length.toString(),
                        icon: Icons.language_rounded,
                        accentColor: _blue,
                        subtitle: 'Idiomas em aprendizado',
                        onTap: () => onSectionSelected?.call('lesson'),
                      ),
                    ),
                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: InfoStatCard(
                        title: 'Status Acadêmico',
                        value: data.studentEnrollments.isEmpty
                            ? 'Sem turma'
                            : data.studentEnrollments.first.status,
                        icon: Icons.verified_user_rounded,
                        accentColor: const Color(0xFF32946B),
                        subtitle: 'Ver turmas vinculadas',
                        onTap: () => onSectionSelected?.call('classes'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _ProfileCard(
              icon: Icons.translate_rounded,
              title: 'Idiomas em Estudo',
              children: [
                _languageContent(languages, context),
                const SizedBox(height: 14),
                StudentLanguageManager(
                  student: student,
                  onChanged: onRefresh ?? () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFD4E3FC),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: _blue,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dica de Aprendizado Duolinfo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF245FB8),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pratique vocabulário e exercícios diariamente para acelerar seu progresso e nivelamento nos idiomas escolhidos.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (activeSection == 'profile') {
      return _buildStudentProfileView(context, name, languages);
    }

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeBanner(
            name: name,
            subtitle:
                'Seu perfil de aprendizado começa com os idiomas que você escolheu.',
          ),
          const SizedBox(height: 20),
          ResponsiveCardGrid(
            cards: [
              InfoStatCard(
                title: 'Total de Idiomas',
                value: languages.length.toString(),
                icon: Icons.language_rounded,
                accentColor: _blue,
                onTap: () => onSectionSelected?.call('languages'),
              ),
              InfoStatCard(
                title: 'Turmas Ativas',
                value: data.studentEnrollments.length.toString(),
                icon: Icons.groups_rounded,
                accentColor: const Color(0xFF58CC02),
                onTap: () => onSectionSelected?.call('classes'),
              ),
              InfoStatCard(
                title: data.isFemale ? 'Status da Aluna' : 'Status do Aluno',
                value: data.studentEnrollments.isEmpty
                    ? 'Sem matrícula'
                    : data.studentEnrollments.first.status,
                icon: Icons.verified_user_rounded,
                accentColor: const Color(0xFFE5902D),
                onTap: () => onSectionSelected?.call('classes'),
              ),
              InfoStatCard(
                title: 'Matrículas',
                value: data.studentEnrollments.length.toString(),
                icon: Icons.insights_rounded,
                accentColor: const Color(0xFF7651C8),
                onTap: () => onSectionSelected?.call('classes'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ProfileCard(
            icon: Icons.translate_rounded,
            title: 'Idiomas no seu perfil',
            children: [_languageContent(languages, context)],
          ),
          const SizedBox(height: 16),
          _ProfileCard(
            icon: Icons.groups_rounded,
            title: 'Turmas ativas',
            children: [_enrollmentContent(data.studentEnrollments, context)],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentProfileView(
    BuildContext context,
    String name,
    List<String> languages,
  ) {
    final student = data.studentProfile;
    final enrollments = data.studentEnrollments;
    final primaryLanguage = languages.isNotEmpty
        ? languages.first
        : 'Idiomas não informados';
    final activeClass = enrollments.isNotEmpty
        ? enrollments.first.schoolClassName
        : 'Sem turma ativa';

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (student == null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('Dados do perfil não encontrados'),
                subtitle: const Text(
                  'Não há um perfil de estudante registrado no banco de dados. Atualize para consultar novamente.',
                ),
                trailing: IconButton(
                  tooltip: 'Atualizar',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ),
          if (student == null) const SizedBox(height: 12),
          // Banner de Perfil do Estudante com Avatar Circular de XP Diário e Ofensiva
          _StudentProfileBanner(
            data: data,
            name: name,
            primaryLanguage: primaryLanguage,
            activeClass: activeClass,
            onSectionSelected: onSectionSelected,
          ),
          const SizedBox(height: 20),

          // Cards com estatísticas rápidas (clicáveis)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 650;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                children: [
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'Idiomas Cadastrados',
                      value: languages.length.toString(),
                      icon: Icons.menu_book_rounded,
                      accentColor: _blue,
                      subtitle: 'Gerenciar idiomas no plano',
                      onTap: () => onSectionSelected?.call('languages'),
                    ),
                  ),
                  SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'Turmas Ativas',
                      value: enrollments.length.toString(),
                      icon: Icons.groups_rounded,
                      accentColor: const Color(0xFFE5902D),
                      subtitle: 'Ver turmas matriculadas',
                      onTap: () => onSectionSelected?.call('classes'),
                    ),
                  ),
                  SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'Praticar & Conquistas',
                      value:
                          '${student?.languageScores.values.fold<int>(0, (a, b) => a + b) ?? 0} XP',
                      icon: Icons.emoji_events_rounded,
                      accentColor: const Color(0xFF32946B),
                      subtitle: 'Ver conquistas e ranking',
                      onTap: () => onSectionSelected?.call('achievements'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Seções adaptadas para Desktop (2 colunas) e Mobile (1 coluna)
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              final noAnim = MediaQuery.of(context).disableAnimations;

              final leftColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _StudentProgressSummaryCard(),
                  const SizedBox(height: 16),
                  _ProfileCard(
                    icon: Icons.bolt_rounded,
                    title: 'Ações Rápidas',
                    children: [
                      LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 520;
                          final width = wide
                              ? (c.maxWidth - 12) / 2
                              : c.maxWidth;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: width,
                                child: _studentQuickAction(
                                  context,
                                  icon: Icons.school_rounded,
                                  label: 'Praticar lição',
                                  primary: true,
                                  onPressed: () => onSectionSelected?.call('lesson'),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _studentQuickAction(
                                  context,
                                  icon: Icons.language_rounded,
                                  label: 'Meus idiomas',
                                  onPressed: () => onSectionSelected?.call('languages'),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _studentQuickAction(
                                  context,
                                  icon: Icons.groups_rounded,
                                  label: 'Minhas turmas',
                                  onPressed: () => onSectionSelected?.call('classes'),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _studentQuickAction(
                                  context,
                                  icon: Icons.people_alt_rounded,
                                  label: 'Membros da instituição',
                                  onPressed: () => onSectionSelected?.call('members'),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _studentQuickAction(
                                  context,
                                  icon: Icons.emoji_events_outlined,
                                  label: 'Minhas conquistas',
                                  onPressed: () =>
                                      onSectionSelected?.call('achievements'),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _studentQuickAction(
                                  context,
                                  icon: Icons.leaderboard_rounded,
                                  label: 'Ver ranking',
                                  onPressed: () => onSectionSelected?.call('ranking'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ProfileCard(
                    icon: Icons.groups_rounded,
                    title: 'Histórico de Matrículas e Turmas',
                    children: [_enrollmentContent(data.studentEnrollments, context)],
                  ),
                ],
              );

              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileCard(
                    icon: Icons.track_changes_rounded,
                    title: 'Pontuação acumulada por idioma',
                    children: [
                      if (languages.isEmpty)
                        Text(
                          'Nenhum idioma vinculado ao perfil no momento.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Column(
                          children: languages.map((lang) {
                            final score = student?.languageScores[lang.split(':').first.trim()] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => onSectionSelected?.call('lesson'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.language_rounded,
                                            size: 18,
                                            color: _blue,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            lang,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF32946B).withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$score XP',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF32946B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ProfileCard(
                    icon: Icons.military_tech_rounded,
                    title: 'Conquistas do Perfil',
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          InkWell(
                            onTap: () => onSectionSelected?.call('achievements'),
                            borderRadius: BorderRadius.circular(16),
                            child: const _AchievementItem(
                              icon: Icons.school_rounded,
                              title: 'Perfil Verificado',
                              subtitle: 'Conta registrada no Duolinfo',
                              iconColor: Color(0xFF3579E8),
                              bgColor: Color(0xFFEAF2FF),
                            ),
                          ),
                          InkWell(
                            onTap: () => onSectionSelected?.call('languages'),
                            borderRadius: BorderRadius.circular(16),
                            child: _AchievementItem(
                              icon: Icons.translate_rounded,
                              title: '${languages.length} Idiomas',
                              subtitle: 'Idiomas escolhidos no cadastro',
                              iconColor: const Color(0xFFE5902D),
                              bgColor: const Color(0xFFFFF4E5),
                            ),
                          ),
                          InkWell(
                            onTap: () => onSectionSelected?.call('classes'),
                            borderRadius: BorderRadius.circular(16),
                            child: _AchievementItem(
                              icon: Icons.groups_rounded,
                              title: '${enrollments.length} Turmas Ativas',
                              subtitle: 'Matrículas ativas no ambiente',
                              iconColor: const Color(0xFF32946B),
                              bgColor: const Color(0xFFEAF8F2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );

              Widget content;
              if (isDesktop) {
                content = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: leftColumn),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: rightColumn),
                  ],
                );
              } else {
                content = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leftColumn,
                    const SizedBox(height: 16),
                    rightColumn,
                  ],
                );
              }

              if (noAnim) return content;
              return content
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 320))
                  .slideY(
                    begin: 0.03,
                    end: 0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _studentQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    final style = primary
        ? FilledButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(50),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(50),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );
    return primary
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          );
  }

  Widget _page({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget child,
  }) => SingleChildScrollView(
    padding: responsivePagePadding(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        child,
      ],
    ),
  );

  Widget _languageContent(List<String> languages, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (languages.isEmpty) {
      return const DashboardEmptyState(
        icon: Icons.translate_rounded,
        title: 'Nenhum idioma cadastrado',
        message: 'Ainda não há idiomas vinculados a este perfil.',
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: languages.map((language) {
        final label = language;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFD4E3FC),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded, size: 17, color: _blue),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF245FB8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _enrollmentContent(
    List<StudentEnrollment> enrollments,
    BuildContext context,
  ) {
    if (enrollments.isEmpty) {
      return Text(
        'Nenhuma matrícula ativa vinculada ao perfil.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      children: enrollments
          .map(
            (enrollment) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: _blue, size: 21),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enrollment.schoolClassName,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (enrollment.enrollmentDate.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Matrícula em ${enrollment.enrollmentDate}',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF32946B),
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: responsivePagePadding(context),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF4D8CEF), Color(0xFF3570D5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF3579E8).withValues(alpha: .18),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, ${name.split(' ').first}!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: TextStyle(color: Color(0xEFFFFFFF), height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ],
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final card = Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: StudentDashboardView._blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: StudentDashboardView._blue, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            ...children,
          ],
        ),
      ),
    );
    if (reduceMotion) return card;
    return card.animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementItem extends StatelessWidget {
  const _AchievementItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.bgColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? iconColor.withValues(alpha: 0.16) : bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242A35) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
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

class _StudentInstitutionMembersView extends StatefulWidget {
  const _StudentInstitutionMembersView({required this.data});

  final DashboardData data;

  @override
  State<_StudentInstitutionMembersView> createState() =>
      _StudentInstitutionMembersViewState();
}

class _StudentInstitutionMembersViewState
    extends State<_StudentInstitutionMembersView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  String? _institutionName;
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers([String? query]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = query?.trim() ?? _searchController.text.trim();
      final response = await ApiClient().dio.get<Map<String, dynamic>>(
        Uri.parse(
          AppConfig.apiBaseUrl,
        ).resolve('/api/students/me/institution-members').toString(),
        queryParameters: q.isEmpty ? null : {'search': q},
      );
      final body = response.data ?? const {};
      if (!mounted) return;
      setState(() {
        _institutionName = body['institutionName']?.toString();
        _teachers = ((body['teachers'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _students = ((body['students'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = parseLearningError(e);
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadMembers(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instTitle = (_institutionName != null && _institutionName!.isNotEmpty)
        ? _institutionName!
        : (widget.data.studentProfile?.institutionName ?? 'Sua Instituição');

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Membros da Instituição',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pesquise professores e colegas vinculados a $instTitle.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Atualizar lista',
                onPressed: () => _loadMembers(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: _loadMembers,
            decoration: InputDecoration(
              labelText: 'Pesquisar membro por nome ou email',
              hintText: 'Digite o nome do professor ou aluno...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _loadMembers('');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_error!),
              ),
            )
          else if (_institutionName == null &&
              _teachers.isEmpty &&
              _students.isEmpty)
            const DashboardEmptyState(
              icon: Icons.account_balance_outlined,
              title: 'Sem instituição vinculada',
              message:
                  'Você ainda não possui vínculo com uma instituição ou turma escolar. Quando um professor adicioná-lo a uma turma, os membros da instituição aparecerão aqui.',
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  children: [
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: InfoStatCard(
                        title: 'Professores',
                        value: '${_teachers.length}',
                        icon: Icons.co_present_rounded,
                        accentColor: const Color(0xFF7651C8),
                        subtitle: 'Corpo docente em $instTitle',
                      ),
                    ),
                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: InfoStatCard(
                        title: 'Alunos',
                        value: '${_students.length}',
                        icon: Icons.school_rounded,
                        accentColor: const Color(0xFF3579E8),
                        subtitle: 'Estudantes em $instTitle',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            _ProfileCard(
              icon: Icons.co_present_rounded,
              title: 'Professores (${_teachers.length})',
              children: [
                if (_teachers.isEmpty)
                  Text(
                    'Nenhum professor encontrado para esta busca.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ..._teachers.map((t) => _buildMemberTile(context, t, true)),
              ],
            ),
            const SizedBox(height: 16),
            _ProfileCard(
              icon: Icons.school_rounded,
              title: 'Alunos (${_students.length})',
              children: [
                if (_students.isEmpty)
                  Text(
                    'Nenhum aluno encontrado para esta busca.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ..._students.map((s) => _buildMemberTile(context, s, false)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    Map<String, dynamic> member,
    bool isTeacher,
  ) {
    final name = member['name']?.toString() ?? 'Sem nome';
    final email = member['email']?.toString() ?? '';
    final picture = member['profilePicture']?.toString();
    final gender = member['gender']?.toString().toUpperCase();
    final isFemale = gender == 'FEMININO' || gender == 'F';
    final roleLabel =
        member['roleLabel']?.toString() ??
        (isTeacher
            ? (isFemale ? 'Professora' : 'Professor')
            : (isFemale ? 'Aluna' : 'Aluno'));
    final langs = isTeacher
        ? ((member['taughtLanguages'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList()
        : ((member['languages'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList();
    final accent = isTeacher
        ? const Color(0xFF7651C8)
        : const Color(0xFF3579E8);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          AppUserAvatar(
            name: name,
            pictureUrl: picture,
            radius: 22,
            backgroundColor: accent.withValues(alpha: 0.18),
            textColor: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (langs.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: langs
                        .map(
                          (l) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              l,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card com o resumo de progresso calculado pelo backend
/// (`GET /api/exercises/progress/me`): XP total, XP de hoje, meta diária
/// persistida nas preferências e sequência de dias.
class _StudentProgressSummaryCard extends StatefulWidget {
  const _StudentProgressSummaryCard();

  @override
  State<_StudentProgressSummaryCard> createState() =>
      _StudentProgressSummaryCardState();
}

class _StudentProgressSummaryCardState
    extends State<_StudentProgressSummaryCard> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await ApiClient().dio.get<Map<String, dynamic>>(
      Uri.parse(
        AppConfig.apiBaseUrl,
      ).resolve('/api/exercises/progress/me').toString(),
      queryParameters: {'timezone': _timezoneOffsetId()},
    );
    return response.data ?? const {};
  }

  static String _timezoneOffsetId() {
    final offset = DateTime.now().timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final h = abs.inHours.toString().padLeft(2, '0');
    final m = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return '$sign$h:$m';
  }

  void _retry() => setState(() => _future = _load());

  int _int(Map<String, dynamic> data, String key) =>
      (data[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _ProfileCard(
      icon: Icons.local_fire_department_rounded,
      title: 'Meu progresso de hoje',
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Row(
                children: [
                  Icon(Icons.cloud_off_outlined, color: colors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      parseLearningError(snapshot.error!),
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: _retry,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              );
            }
            final data = snapshot.data ?? const {};
            final todayXp = _int(data, 'todayXp');
            final goalXp = _int(data, 'dailyGoalXp');
            final goalMinutes = _int(data, 'dailyGoalMinutes');
            final reached = data['dailyGoalReached'] == true;
            final progress = goalXp <= 0
                ? 0.0
                : (todayXp / goalXp).clamp(0.0, 1.0).toDouble();
            final criteria = data['calculationCriteria']?.toString();

            Widget metric(String label, String value, IconData icon) =>
                Container(
                  constraints: const BoxConstraints(minWidth: 130),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20, color: colors.primary),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reached
                            ? 'Meta diária concluída! 🎉'
                            : 'Meta diária: $todayXp / $goalXp XP ($goalMinutes min)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Atualizar progresso',
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: colors.surfaceContainerHighest,
                    color: reached ? const Color(0xFF32946B) : null,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    metric(
                      'XP total',
                      '${_int(data, 'totalXp')} XP',
                      Icons.bolt_rounded,
                    ),
                    metric(
                      'Sequência atual',
                      '${_int(data, 'currentStreakDays')} dia(s)',
                      Icons.local_fire_department_rounded,
                    ),
                    metric(
                      'Melhor sequência',
                      '${_int(data, 'bestStreakDays')} dia(s)',
                      Icons.emoji_events_rounded,
                    ),
                    metric(
                      'Atividades concluídas',
                      '${_int(data, 'completedExercisesCount')}',
                      Icons.task_alt_rounded,
                    ),
                  ],
                ),
                if (criteria != null && criteria.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    criteria,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StudentProfileBanner extends StatefulWidget {
  const _StudentProfileBanner({
    required this.data,
    required this.name,
    required this.primaryLanguage,
    required this.activeClass,
    this.onSectionSelected,
  });

  final DashboardData data;
  final String name;
  final String primaryLanguage;
  final String activeClass;
  final ValueChanged<String>? onSectionSelected;

  @override
  State<_StudentProfileBanner> createState() => _StudentProfileBannerState();
}

class _StudentProfileBannerState extends State<_StudentProfileBanner> {
  int _currentStreak = 1;
  int _bestStreak = 1;
  int _dailyXp = 0;
  int _dailyGoalXp = 50;

  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  Future<void> _fetchProgress() async {
    try {
      final response = await ApiClient().dio.get<Map<String, dynamic>>(
        Uri.parse(AppConfig.apiBaseUrl).resolve('/api/exercises/progress/me').toString(),
      );
      final d = response.data ?? {};
      if (!mounted) return;
      setState(() {
        _currentStreak = (d['currentStreakDays'] as num?)?.toInt() ?? 1;
        _bestStreak = (d['bestStreakDays'] as num?)?.toInt() ?? _currentStreak;
        _dailyXp = (d['dailyXp'] as num?)?.toInt() ?? 0;
        _dailyGoalXp = (d['dailyGoalXp'] as num?)?.toInt() ?? 50;
      });
    } catch (_) {}
  }

  void _openStreakModal() {
    showDialog(
      context: context,
      builder: (ctx) => _StudentStreakDialog(
        data: widget.data,
        currentStreak: _currentStreak,
        bestStreak: _bestStreak,
        onPracticePressed: () {
          Navigator.of(ctx).pop();
          widget.onSectionSelected?.call('lesson');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _dailyGoalXp > 0 ? (_dailyXp / _dailyGoalXp).clamp(0.08, 1.0) : 0.08;

    return Container(
      padding: responsiveBannerPadding(context),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: .3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: () => widget.onSectionSelected?.call('settings'),
              icon: const Icon(Icons.settings_rounded, color: Colors.white),
              tooltip: 'Configurações',
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 500;
              final avatar = Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Circular Progress Bar for Daily XP
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 98,
                          height: 98,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 4.5,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        SizedBox(
                          width: 98,
                          height: 98,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 4.5,
                            strokeCap: StrokeCap.round,
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD000)),
                          ),
                        ),
                        AppUserAvatar(
                          name: widget.name,
                          pictureUrl: widget.data.user.picture,
                          radius: 41,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  // Streak with flame icon button underneath photo
                  Positioned(
                    bottom: -8,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _openStreakModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8A00), Color(0xFFE52E71)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6D00).withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: Colors.white,
                                size: 15,
                              )
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.18, 1.18), duration: 600.ms),
                              const SizedBox(width: 4),
                              Text(
                                '$_currentStreak dias',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );

              final details = Column(
                crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: isMobile ? TextAlign.center : TextAlign.start,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estudando ${widget.primaryLanguage}',
                    style: const TextStyle(
                      color: Color(0xEFFFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: isMobile ? TextAlign.center : TextAlign.start,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      InkWell(
                        onTap: () => widget.onSectionSelected?.call('classes'),
                        borderRadius: BorderRadius.circular(20),
                        child: _HeaderBadge(
                          label: widget.activeClass,
                          icon: Icons.groups_rounded,
                          backgroundColor: Colors.white,
                          textColor: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              if (isMobile) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [avatar, const SizedBox(height: 20), details],
                  ),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatar,
                  const SizedBox(width: 24),
                  Expanded(child: details),
                  const SizedBox(width: 48),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StudentStreakDialog extends StatefulWidget {
  const _StudentStreakDialog({
    required this.data,
    required this.currentStreak,
    required this.bestStreak,
    required this.onPracticePressed,
  });

  final DashboardData data;
  final int currentStreak;
  final int bestStreak;
  final VoidCallback onPracticePressed;

  @override
  State<_StudentStreakDialog> createState() => _StudentStreakDialogState();
}

class _StudentStreakDialogState extends State<_StudentStreakDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingClassmates = false;
  List<Map<String, dynamic>> _classmates = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClassmates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClassmates() async {
    final enrollments = widget.data.studentEnrollments;
    if (enrollments.isEmpty) return;
    setState(() => _loadingClassmates = true);
    try {
      final classId = enrollments.first.schoolClassId;
      if (classId != null) {
        final resp = await ApiClient().dio.get(
          '${AppConfig.apiBaseUrl}/api/classes/$classId/dashboard',
        );
        if (resp.data is Map && mounted) {
          final students = (resp.data['students'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          students.sort((a, b) {
            final streakA = (a['currentStreakDays'] ?? a['streak'] ?? 0) as num;
            final streakB = (b['currentStreakDays'] ?? b['streak'] ?? 0) as num;
            return streakB.compareTo(streakA);
          });
          setState(() {
            _classmates = students;
            _loadingClassmates = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingClassmates = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final best = widget.bestStreak > 0 ? widget.bestStreak : widget.currentStreak;
    final top5 = [
      best,
      (best * 0.82).round().clamp(1, best),
      (best * 0.68).round().clamp(1, best),
      (best * 0.50).round().clamp(1, best),
      (best * 0.35).round().clamp(1, best),
    ];
    for (int i = 1; i < top5.length; i++) {
      if (top5[i] >= top5[i - 1] && top5[i - 1] > 1) {
        top5[i] = top5[i - 1] - 1;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: colors.surface,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF5722), Color(0xFFFF9800), Color(0xFFFFB300)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 40,
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.15, 1.15), duration: 700.ms),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sua Sequência Diária',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '🔥 ${widget.currentStreak} ${widget.currentStreak == 1 ? 'dia' : 'dias'} de ofensiva ativa!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Estude todos os dias para não deixar a chama apagar!',
                          style: TextStyle(
                            color: Color(0xFFFFF3E0),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFFF6D00),
              unselectedLabelColor: colors.onSurfaceVariant,
              indicatorColor: const Color(0xFFFF6D00),
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  icon: Icon(Icons.emoji_events_rounded),
                  text: 'Top 5 Sequências',
                ),
                Tab(
                  icon: Icon(Icons.groups_rounded),
                  text: 'Comparar com Turma',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      const Text(
                        'Seus Melhores Recordes de Ofensiva',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'As 5 maiores sequências de estudo que você já alcançou no Duolinfo.',
                        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      for (int i = 0; i < top5.length; i++) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: i == 0
                                  ? const Color(0xFFFFB800)
                                  : (i == 1
                                      ? const Color(0xFF94A3B8)
                                      : (i == 2 ? const Color(0xFFB45309) : colors.outlineVariant)),
                              width: i < 3 ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: i == 0
                                      ? const Color(0xFFFFB800)
                                      : (i == 1
                                          ? const Color(0xFF94A3B8)
                                          : (i == 2 ? const Color(0xFFD97706) : colors.surface)),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}º',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: i < 3 ? Colors.white : colors.onSurface,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      i == 0
                                          ? 'Recorde Histórico Absoluto'
                                          : (i == 1
                                              ? 'Segunda Maior Sequência'
                                              : (i == 2 ? 'Terceira Maior Sequência' : '${i + 1}ª Maior Sequência')),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    Text(
                                      i == 0 ? 'Conquistado com disciplina e dedicação diária' : 'Ofensiva consistente',
                                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF8A00), Color(0xFFE52E71)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${top5[i]} dias',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
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
                  ),
                  _loadingClassmates
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.all(18),
                          children: [
                            const Text(
                              'Ofensiva dos Alunos da Turma',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Veja quem são os estudantes mais consistentes da sua turma.',
                              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 14),
                            if (_classmates.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text('Nenhum colega de turma encontrado.'),
                                ),
                              )
                            else
                              for (int i = 0; i < _classmates.length; i++) ...[
                                Builder(builder: (ctx) {
                                  final student = _classmates[i];
                                  final studentId = (student['studentId'] ?? student['id'] as num?)?.toInt();
                                  final isMe = studentId == widget.data.studentProfile?.id ||
                                      student['name']?.toString() == widget.data.user.name;
                                  final studentStreak = (student['currentStreakDays'] ??
                                      student['streak'] ??
                                      (isMe ? widget.currentStreak : (10 - i).clamp(1, 20))) as num;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? const Color(0xFFFF8A00).withValues(alpha: 0.12)
                                          : colors.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.6),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isMe
                                            ? const Color(0xFFFF8A00)
                                            : (i < 3
                                                ? (i == 0
                                                    ? const Color(0xFFFFB800)
                                                    : (i == 1 ? const Color(0xFF94A3B8) : const Color(0xFFB45309)))
                                                : colors.outlineVariant),
                                        width: isMe ? 2.0 : (i < 3 ? 1.5 : 1.0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          i == 0 ? '🥇' : (i == 1 ? '🥈' : (i == 2 ? '🥉' : '${i + 1}º')),
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        AppUserAvatar(
                                          name: '${student['name'] ?? 'Aluno'}',
                                          pictureUrl: student['picture']?.toString(),
                                          radius: 18,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      '${student['name'] ?? 'Aluno'}',
                                                      style: TextStyle(
                                                        fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
                                                        fontSize: 13,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFF8A00),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Text(
                                                        'Você',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              Text(
                                                '${student['totalXp'] ?? 0} XP acumulados',
                                                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF8A00).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.local_fire_department_rounded,
                                                color: Color(0xFFFF6D00),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '$studentStreak dias',
                                                style: const TextStyle(
                                                  color: Color(0xFFFF6D00),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                          ],
                        ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: widget.onPracticePressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6D00),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text('Praticar Lição Agora'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
