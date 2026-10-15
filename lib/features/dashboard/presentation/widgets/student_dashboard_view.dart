import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/student_enrollment.dart';
import 'app_user_avatar.dart';
import 'dashboard_empty_state.dart';
import 'info_stat_card.dart';
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
    if (activeSection == 'settings') {
      return StudentSettingsView(
        data: data,
        onBackToProfile: () => onSectionSelected?.call('profile'),
        onLogout: onLogout ?? () {},
        onRefresh: onRefresh,
      );
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
                        accentColor: Color(0xFF32946B),
                        subtitle: 'Matrícula regularizada',
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
              children: [_languageContent(languages, context)],
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD4E3FC)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: _blue, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dica de Aprendizado Duolinfo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF245FB8),
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
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
              ),
              InfoStatCard(
                title: 'Turmas Ativas',
                value: data.studentEnrollments.length.toString(),
                icon: Icons.groups_rounded,
                accentColor: const Color(0xFF58CC02),
              ),
              InfoStatCard(
                title: 'Status do Aluno',
                value: data.studentEnrollments.isEmpty
                    ? 'Sem matrícula'
                    : data.studentEnrollments.first.status,
                icon: Icons.verified_user_rounded,
                accentColor: const Color(0xFFE5902D),
              ),
              InfoStatCard(
                title: 'Matrículas',
                value: data.studentEnrollments.length.toString(),
                icon: Icons.insights_rounded,
                accentColor: const Color(0xFF7651C8),
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
          const SizedBox(height: 16),
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
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => onSectionSelected?.call('settings'),
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Configurações',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                              'Estudante',
                              style: TextStyle(
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
                          style: TextStyle(
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
                          'Estudando $primaryLanguage · Aluno Duolinfo',
                          style: TextStyle(
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
                            _HeaderBadge(
                              label: activeClass,
                              icon: Icons.groups_rounded,
                              backgroundColor: Colors.white,
                              textColor: _blue,
                            ),
                            _HeaderBadge(
                              label: '${languages.length} Idiomas',
                              icon: Icons.language_rounded,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              textColor: Colors.white,
                            ),
                            if (enrollments.isNotEmpty)
                              _HeaderBadge(
                                label: 'Matrícula ${enrollments.first.status}',
                                icon: Icons.check_circle_outline_rounded,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                textColor: Colors.white,
                              ),
                          ],
                        ),
                      ],
                    );
                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [avatar, const SizedBox(height: 16), details],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        avatar,
                        const SizedBox(width: 20),
                        Expanded(child: details),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Cards com estatísticas rápidas
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
                      subtitle: 'Idiomas no plano de estudo',
                    ),
                  ),
                  SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'Turmas Ativas',
                      value: enrollments.length.toString(),
                      icon: Icons.emoji_events_rounded,
                      accentColor: const Color(0xFFE5902D),
                      subtitle: 'Matrículas ativas no sistema',
                    ),
                  ),
                  SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'Situação Acadêmica',
                      value: enrollments.length.toString(),
                      icon: Icons.verified_rounded,
                      accentColor: Color(0xFF32946B),
                      subtitle: 'Matrícula confirmada',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF32946B),
                                ),
                              ),
                            ],
                          ),
                        ],
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
                  _AchievementItem(
                    icon: Icons.school_rounded,
                    title: 'Perfil Verificado',
                    subtitle: 'Conta registrada no Duolinfo',
                    iconColor: const Color(0xFF3579E8),
                    bgColor: const Color(0xFFEAF2FF),
                  ),
                  _AchievementItem(
                    icon: Icons.translate_rounded,
                    title: '${languages.length} Idiomas',
                    subtitle: 'Idiomas escolhidos no cadastro',
                    iconColor: const Color(0xFFE5902D),
                    bgColor: const Color(0xFFFFF4E5),
                  ),
                  _AchievementItem(
                    icon: Icons.groups_rounded,
                    title: '${enrollments.length} Turmas Ativas',
                    subtitle: 'Matrículas ativas no ambiente',
                    iconColor: const Color(0xFF32946B),
                    bgColor: const Color(0xFFEAF8F2),
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
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD4E3FC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded, size: 17, color: _blue),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Color(0xFF245FB8),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Não informado' : value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
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
