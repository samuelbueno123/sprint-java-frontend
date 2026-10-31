import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/teacher_class_assignment.dart';
import '../../domain/entities/teacher_profile.dart';
import 'app_user_avatar.dart';
import 'info_stat_card.dart';
import 'responsive_layout.dart';
import 'teacher_settings_view.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import 'learning_features.dart';

class TeacherDashboardView extends StatelessWidget {
  const TeacherDashboardView({
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

  static const _purple = Color(0xFF7651C8);

  @override
  Widget build(BuildContext context) {
    if (activeSection == 'settings') {
      return TeacherSettingsView(
        data: data,
        onBackToProfile: () => onSectionSelected?.call('profile'),
        onLogout: onLogout ?? () {},
        onRefresh: onRefresh,
      );
    }

    final teacher = data.teacherProfile;
    if (teacher == null) {
      return _teacherProfileUnavailable(context);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeSection == 'languages') {
      return _page(
        context: context,
        title: 'Ensino e idiomas',
        subtitle: 'Idiomas lecionados, especializações e atuação acadêmica.',
        child: Column(
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
                        title: 'Idiomas Lecionados',
                        value: teacher.taughtLanguages.length.toString(),
                        icon: Icons.record_voice_over_rounded,
                        accentColor: _purple,
                        subtitle: 'Idiomas sob sua ministração',
                      ),
                    ),
                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: InfoStatCard(
                        title: 'Especializações',
                        value: teacher.specializationAreas.length.toString(),
                        icon: Icons.workspace_premium_outlined,
                        accentColor: const Color(0xFFE5902D),
                        subtitle: 'Áreas de domínio técnico',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _ProfileCard(
              icon: Icons.record_voice_over_rounded,
              title: 'Idiomas lecionados',
              child: _tagList(teacher.taughtLanguages, _purple, context),
            ),
            const SizedBox(height: 16),
            _ProfileCard(
              icon: Icons.workspace_premium_outlined,
              title: 'Áreas de especialização',
              child: _tagList(
                teacher.specializationAreas,
                const Color(0xFFE5902D),
                context,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  final languages = TextEditingController(
                    text: teacher.taughtLanguages.join(', '),
                  );
                  final areas = TextEditingController(
                    text: teacher.specializationAreas.join(', '),
                  );
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      title: const Text('Gerenciar idiomas e especializações'),
                      content: SizedBox(
                        width: 460,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: languages,
                              decoration: const InputDecoration(
                                labelText:
                                    'Idiomas lecionados (separados por vírgula)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: areas,
                              decoration: const InputDecoration(
                                labelText:
                                    'Especializações (separadas por vírgula)',
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Salvar'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && teacher.id != null) {
                    try {
                      await ApiClient().dio.put(
                        '${AppConfig.teachersEndpoint}/${teacher.id}',
                        data: {
                          'name': teacher.name,
                          'email': teacher.email,
                          'googleId': teacher.googleId,
                          'institutionId': teacher.institutionId,
                          'taughtLanguages': languages.text
                              .split(',')
                              .map((v) => v.trim())
                              .where((v) => v.isNotEmpty)
                              .toList(),
                          'specializationAreas': areas.text
                              .split(',')
                              .map((v) => v.trim())
                              .where((v) => v.isNotEmpty)
                              .toList(),
                          'bibliography': teacher.bibliography,
                        },
                      );
                      onRefresh?.call();
                    } catch (e) {
                      if (context.mounted) showLearningError(context, e);
                    }
                  }
                  Future.delayed(const Duration(milliseconds: 400), () {
                    languages.dispose();
                    areas.dispose();
                  });
                },
                icon: const Icon(Icons.edit),
                label: const Text(
                  'Gerenciar idiomas lecionados / atualizar especializações',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF261E3A)
                    : const Color(0xFFF3EFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF4C3575)
                      : const Color(0xFFE2D6FF),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, color: _purple, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Orientações Didáticas',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF5B3BA6),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mantenha os conteúdos das turmas atualizados para garantir um acompanhamento eficiente do aprendizado dos alunos.',
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
      return _buildTeacherProfileView(context, teacher);
    }

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeBanner(name: teacher.name, institution: teacher.institution),
          const SizedBox(height: 20),
          ResponsiveCardGrid(
            cards: [
              InfoStatCard(
                title: 'Idiomas de Ensino',
                value: teacher.taughtLanguages.length.toString(),
                icon: Icons.record_voice_over_rounded,
                accentColor: _purple,
                onTap: () => onSectionSelected?.call('languages'),
              ),
              InfoStatCard(
                title: 'Especializações',
                value: teacher.specializationAreas.length.toString(),
                icon: Icons.workspace_premium_outlined,
                accentColor: const Color(0xFFE5902D),
                onTap: () => onSectionSelected?.call('languages'),
              ),
              InfoStatCard(
                title: 'Turmas Atribuídas',
                value: data.teacherAssignments.length.toString(),
                icon: Icons.groups_rounded,
                accentColor: const Color(0xFF3579E8),
                onTap: () => onSectionSelected?.call('classes'),
              ),
              InfoStatCard(
                title: 'Instituição',
                value: teacher.institution.isNotEmpty
                    ? teacher.institution
                    : 'Cadastrada',
                icon: Icons.account_balance_rounded,
                accentColor: const Color(0xFF32946B),
                onTap: () => onSectionSelected?.call('classes'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 620;
              return Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: wide ? 1 : 0,
                    fit: wide ? FlexFit.tight : FlexFit.loose,
                    child: _ProfileCard(
                      icon: Icons.translate_rounded,
                      title: 'Idiomas lecionados',
                      child: _tagList(
                        teacher.taughtLanguages,
                        _purple,
                        context,
                      ),
                    ),
                  ),
                  SizedBox(width: wide ? 14 : 0, height: wide ? 0 : 14),
                  Flexible(
                    flex: wide ? 1 : 0,
                    fit: wide ? FlexFit.tight : FlexFit.loose,
                    child: _ProfileCard(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Especializações',
                      child: _tagList(
                        teacher.specializationAreas,
                        const Color(0xFFE5902D),
                        context,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _profileContent(teacher, context),
        ],
      ),
    );
  }

  Widget _teacherProfileUnavailable(BuildContext context) => _page(
    context: context,
    title: activeSection == 'languages'
        ? 'Ensino e idiomas'
        : (data.isFemale ? 'Perfil da professora' : 'Perfil do professor'),
    subtitle: 'Resumo da conta e das turmas vinculadas ao seu perfil.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: const Text('Dados do perfil docente não encontrados'),
            subtitle: const Text(
              'Não há um cadastro de professor disponível no banco de dados. Atualize para consultar novamente.',
            ),
            trailing: IconButton(
              tooltip: 'Atualizar',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ),
        const SizedBox(height: 16),
        InfoStatCard(
          title: 'Turmas vinculadas',
          value: data.teacherAssignments.length.toString(),
          icon: Icons.groups_outlined,
          accentColor: _purple,
          subtitle: 'Atribuições recebidas da API',
          onTap: () => onSectionSelected?.call('classes'),
        ),
        if (activeSection != 'languages') ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: responsiveCardPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Turmas atribuídas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (data.teacherAssignments.isEmpty)
                    const Text(
                      'Não há turmas registradas no banco de dados. Atualize para consultar novamente.',
                    )
                  else
                    for (final assignment in data.teacherAssignments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.class_outlined),
                        title: Text(assignment.schoolClassName),
                        subtitle: Text('Desde ${assignment.startDate}'),
                        onTap: () => onSectionSelected?.call('classes'),
                      ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildTeacherProfileView(
    BuildContext context,
    TeacherProfile teacher,
  ) {
    final assignments = data.teacherAssignments;
    final activeAssignments = assignments
        .where((assignment) => assignment.isActive)
        .length;
    final isFemale = data.isFemale;
    final roleNoun = isFemale ? 'Professora' : 'Professor';
    final primarySubject = teacher.taughtLanguages.isNotEmpty
        ? '$roleNoun de ${teacher.taughtLanguages.join(', ')}'
        : '$roleNoun Duolinfo';
    final instName = teacher.institution.isNotEmpty
        ? teacher.institution
        : 'Instituição Cadastrada';

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner do Perfil do Professor
          Container(
            padding: responsiveBannerPadding(context),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7651C8), Color(0xFF5B3BA6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7651C8).withValues(alpha: .22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFemale ? 'Painel da Professora' : 'Painel do Professor',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Configurações',
                      onPressed: () => onSectionSelected?.call('settings'),
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                      ),
                      ),
                    IconButton(
                      tooltip: 'Sair da conta',
                      onPressed: onLogout,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                      ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 500;
                    final avatar = AppUserAvatar(
                      name: teacher.name,
                      pictureUrl: data.user.picture,
                      radius: 42,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      textColor: Colors.white,
                    );
                    final details = Column(
                      crossAxisAlignment: isMobile
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          teacher.name,
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
                          '$primarySubject • $instName',
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
                                label: '$activeAssignments Turmas ativas',
                                icon: Icons.groups_rounded,
                                backgroundColor: Colors.white,
                                textColor: _purple,
                              ),
                            ),
                            InkWell(
                              onTap: () => onSectionSelected?.call('languages'),
                              borderRadius: BorderRadius.circular(20),
                              child: _HeaderBadge(
                                label:
                                    '${teacher.taughtLanguages.length} Idiomas',
                                icon: Icons.record_voice_over_rounded,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                textColor: Colors.white,
                              ),
                            ),
                            if (teacher.specializationAreas.isNotEmpty)
                              InkWell(
                                onTap: () =>
                                    onSectionSelected?.call('languages'),
                                borderRadius: BorderRadius.circular(20),
                                child: _HeaderBadge(
                                  label:
                                      '${teacher.specializationAreas.length} Especializações',
                                  icon: Icons.workspace_premium_outlined,
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

          // Métricas rápidas derivadas do perfil e das atribuições da API (clicáveis).
          ResponsiveCardGrid(
            cards: [
              InfoStatCard(
                title: 'Turmas ativas',
                value: activeAssignments.toString(),
                icon: Icons.groups_rounded,
                accentColor: _purple,
                subtitle: 'Gerenciar turmas',
                onTap: () => onSectionSelected?.call('classes'),
              ),
              InfoStatCard(
                title: 'Minhas atividades',
                value: assignments.length.toString(),
                icon: Icons.library_books_outlined,
                accentColor: const Color(0xFF3579E8),
                subtitle: 'Acessar exercícios',
                onTap: () => onSectionSelected?.call('manageExercises'),
              ),
              InfoStatCard(
                title: 'Idiomas lecionados',
                value: teacher.taughtLanguages.length.toString(),
                icon: Icons.record_voice_over_rounded,
                accentColor: const Color(0xFF32946B),
                subtitle: 'Editar idiomas',
                onTap: () => onSectionSelected?.call('languages'),
              ),
              InfoStatCard(
                title: 'Especializações',
                value: teacher.specializationAreas.length.toString(),
                icon: Icons.workspace_premium_outlined,
                accentColor: const Color(0xFFE5902D),
                subtitle: 'Ver competências',
                onTap: () => onSectionSelected?.call('languages'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _ProfileCard(
            icon: Icons.bolt_rounded,
            title: 'Ações Rápidas',
            child: LayoutBuilder(
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
                      child: _teacherQuickAction(
                        context,
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Criar conteúdo',
                        onPressed: () =>
                            onSectionSelected?.call('createExercise'),
                        primary: true,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _teacherQuickAction(
                        context,
                        icon: Icons.groups_outlined,
                        label: 'Gerenciar turmas',
                        onPressed: () => onSectionSelected?.call('classes'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _teacherQuickAction(
                        context,
                        icon: Icons.rate_review_outlined,
                        label: 'Analisar respostas',
                        onPressed: () =>
                            onSectionSelected?.call('reviewExercises'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _teacherQuickAction(
                        context,
                        icon: Icons.trending_up_rounded,
                        label: 'Ver rankings',
                        onPressed: () =>
                            onSectionSelected?.call('teacherRanking'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Seção: Minhas Turmas Atribuídas
          _ProfileCard(
            icon: Icons.groups_rounded,
            title: 'Minhas Turmas e Atribuições',
            child: _assignmentContent(assignments, context),
          ),
          const SizedBox(height: 16),

          // Seção: Competências Docentes
          _ProfileCard(
            icon: Icons.translate_rounded,
            title: 'Competências Docentes & Idiomas',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Idiomas lecionados:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _tagList(teacher.taughtLanguages, _purple, context),
                const SizedBox(height: 16),
                Text(
                  'Áreas de especialização:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _tagList(
                  teacher.specializationAreas,
                  const Color(0xFFE5902D),
                  context,
                ),
              ],
            ),
          ),
          if (teacher.bibliography?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _ProfileCard(
              icon: Icons.menu_book_rounded,
              title: 'Biografia e Mini-Currículo',
              child: Text(
                teacher.bibliography!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ),
          ],
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

  Widget _teacherQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    final style = primary
        ? FilledButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(54),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(54),
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

  Widget _profileContent(TeacherProfile teacher, BuildContext context) =>
      Column(
        children: [
          if (teacher.bibliography?.trim().isNotEmpty == true) ...[
            _ProfileCard(
              icon: Icons.menu_book_rounded,
              title: 'Biografia profissional',
              child: Text(
                teacher.bibliography!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _ProfileCard(
            icon: Icons.groups_rounded,
            title: 'Histórico de turmas',
            child: _assignmentContent(data.teacherAssignments, context),
          ),
        ],
      );

  Widget _assignmentContent(
    List<TeacherClassAssignment> assignments,
    BuildContext context,
  ) {
    if (assignments.isEmpty) {
      return Text(
        'Nenhuma turma vinculada ao perfil.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      children: assignments
          .map(
            (assignment) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onSectionSelected?.call('classes'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        color: assignment.isActive
                            ? _purple
                            : const Color(0xFF9296A5),
                        size: 21,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment.schoolClassName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              assignment.isActive
                                  ? 'Ativa desde ${assignment.startDate}'
                                  : 'Período: ${assignment.startDate} – ${assignment.endDate}',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            if (assignment.reason?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 3),
                              Text(
                                assignment.reason!,
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
                      Text(
                        assignment.isActive ? 'Ativa' : 'Encerrada',
                        style: TextStyle(
                          color: assignment.isActive
                              ? const Color(0xFF32946B)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _tagList(List<String> values, Color color, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (values.isEmpty) {
      return Text(
        'Nenhum dado cadastrado.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (value) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? .22 : .09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: .35)),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.name, required this.institution});

  final String name;
  final String institution;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: responsivePagePadding(context),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF805BCF), Color(0xFF6741B5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7651C8).withValues(alpha: .18),
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
                institution.isNotEmpty
                    ? 'Seu perfil docente • $institution'
                    : 'Seu perfil docente no Duolinfo.',
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
            Icons.co_present_rounded,
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
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

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
              Icon(icon, color: TeacherDashboardView._purple, size: 21),
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
          child,
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
