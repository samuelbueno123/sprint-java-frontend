import 'dart:async';

import 'package:flutter/material.dart';

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
    final studentRoleWord = data.isFemale ? 'Aluna' : 'Aluno';

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
          // Banner de Perfil do Estudante com Avatar e Badges
          Container(
            padding: responsiveBannerPadding(context),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3579E8), Color(0xFF1D52B4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3579E8).withValues(alpha: .22),
                  blurRadius: 18,
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
                    onPressed: () => onSectionSelected?.call('settings'),
                    icon: const Icon(
                      Icons.settings_rounded,
                      color: Colors.white,
                    ),
                    tooltip: 'Configurações',
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 500;
                    final avatar = Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.55),
                              width: 3,
                            ),
                          ),
                        ),
                        AppUserAvatar(
                          name: name,
                          pictureUrl: data.user.picture,
                          radius: 42,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          textColor: Colors.white,
                        ),
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD000),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              studentRoleWord,
                              style: const TextStyle(
                                color: Color(0xFF523E00),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                    final details = Column(
                      crossAxisAlignment: isMobile
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: isMobile
                              ? TextAlign.center
                              : TextAlign.start,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estudando $primaryLanguage · $studentRoleWord Duolinfo',
                          style: const TextStyle(
                            color: Color(0xEFFFFFFF),
                            fontSize: 14,
                          ),
                          textAlign: isMobile
                              ? TextAlign.center
                              : TextAlign.start,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: isMobile
                              ? WrapAlignment.center
                              : WrapAlignment.start,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            InkWell(
                              onTap: () => onSectionSelected?.call('classes'),
                              borderRadius: BorderRadius.circular(20),
                              child: _HeaderBadge(
                                label: activeClass,
                                icon: Icons.groups_rounded,
                                backgroundColor: Colors.white,
                                textColor: _blue,
                              ),
                            ),
                            InkWell(
                              onTap: () => onSectionSelected?.call('languages'),
                              borderRadius: BorderRadius.circular(20),
                              child: _HeaderBadge(
                                label: '${languages.length} Idiomas',
                                icon: Icons.language_rounded,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                textColor: Colors.white,
                              ),
                            ),
                            if (enrollments.isNotEmpty)
                              InkWell(
                                onTap: () => onSectionSelected?.call('classes'),
                                borderRadius: BorderRadius.circular(20),
                                child: _HeaderBadge(
                                  label:
                                      'Matrícula ${enrollments.first.status}',
                                  icon: Icons.check_circle_outline_rounded,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.2,
                                  ),
                                  textColor: Colors.white,
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
                          children: [avatar, const SizedBox(height: 16), details],
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        avatar,
                        const SizedBox(width: 20),
                        Expanded(child: details),
                        const SizedBox(width: 48),
                      ],
                    );
                  },
                ),
              ],
            ),
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

          // Progresso diário calculado pelo backend (XP, meta e sequência)
          const _StudentProgressSummaryCard(),
          const SizedBox(height: 20),

          // Ações Rápidas do Aluno
          _ProfileCard(
            icon: Icons.bolt_rounded,
            title: 'Ações Rápidas',
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 560;
                  final width = wide
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
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

          // Seção: Progresso por Idioma & Detalhes
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: InkWell(
                        onTap: () => onSectionSelected?.call('lesson'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${student?.languageScores[lang.split(':').first.trim()] ?? 0} XP',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF32946B),
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

          // Conquistas Recentes
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
          const SizedBox(height: 16),

          // Histórico de Matrículas e Turmas
          _ProfileCard(
            icon: Icons.groups_rounded,
            title: 'Histórico de Matrículas e Turmas',
            children: [_enrollmentContent(data.studentEnrollments, context)],
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
  Widget build(BuildContext context) => Card(
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
              Icon(icon, color: StudentDashboardView._blue, size: 21),
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
