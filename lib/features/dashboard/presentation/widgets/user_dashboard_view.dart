import 'package:flutter/material.dart';

import '../../../auth/presentation/pages/student_signup_page.dart';
import '../../../auth/presentation/pages/teacher_signup_page.dart';
import '../../domain/entities/dashboard_data.dart';
import 'app_user_avatar.dart';
import 'responsive_layout.dart';
import 'user_settings_view.dart';

class UserDashboardView extends StatelessWidget {
  const UserDashboardView({
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

  @override
  Widget build(BuildContext context) {
    if (activeSection == 'settings') {
      return UserSettingsView(
        data: data,
        onBackToProfile: () => onSectionSelected?.call('profile'),
        onLogout: onLogout ?? () {},
        onRefresh: onRefresh,
      );
    }

    if (data.hasTeacherProfile) {
      return _buildTeacherApprovalStatus(context);
    }

    if (activeSection == 'profile') {
      return _buildUserProfileView(context);
    }

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5869D8), Color(0xFF7651C8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Bem-vindo, ${data.user.name.split(' ').first}!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sua conta foi autenticada com sucesso! Para começar a usar a plataforma, escolha se você deseja continuar como Estudante ou Professor.',
                      style: TextStyle(color: Color(0xEFFFFFFF), height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Escolha o tipo de perfil:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PendingProfileCard(
                      title: 'Sou Estudante',
                      description: 'Cadastre seus idiomas e acesse cursos.',
                      icon: Icons.school_rounded,
                      color: const Color(0xFF3579E8),
                      onTap: () => _openStudentSignup(context),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _PendingProfileCard(
                      title: 'Sou Professor',
                      description: 'Vincule sua instituição e turmas.',
                      icon: Icons.co_present_rounded,
                      color: const Color(0xFF7651C8),
                      onTap: () => _openTeacherSignup(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherApprovalStatus(BuildContext context) {
    final approved = !data.teacherApprovalPending;
    final color = approved ? const Color(0xFF15803D) : const Color(0xFFD97706);
    final title = approved ? 'Cadastro aprovado' : 'Cadastro em análise';
    final message = approved
        ? 'Seu acesso de professor foi liberado. Atualize o painel para carregar suas permissões.'
        : 'Recebemos sua solicitação para ser professor. Você poderá acessar as funções de ensino depois da aprovação.';

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    approved
                        ? Icons.verified_user_rounded
                        : Icons.pending_actions_rounded,
                    size: 48,
                    color: color,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  if (approved)
                    FilledButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Atualizar acesso'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Atualizar situação'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openStudentSignup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentSignupPage(
          initialEmail: data.user.email,
          initialName: data.user.name,
        ),
      ),
    );
  }

  void _openTeacherSignup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherSignupPage(
          initialEmail: data.user.email,
          initialName: data.user.name,
        ),
      ),
    );
  }

  Widget _buildUserProfileView(BuildContext context) {
    final isMobile = isCompactLayout(context);

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner do Perfil
              Container(
                padding: responsiveBannerPadding(context),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5869D8), Color(0xFF7651C8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5869D8).withValues(alpha: .2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final avatar = AppUserAvatar(
                          name: data.user.name,
                          pictureUrl: data.user.picture,
                          radius: 36,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          textColor: Colors.white,
                        );
                        final details = Column(
                          crossAxisAlignment: isMobile
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.user.name,
                              textAlign: isMobile
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data.user.email,
                              textAlign: isMobile
                                  ? TextAlign.center
                                  : TextAlign.start,
                              softWrap: true,
                              style: TextStyle(
                                color: Color(0xEFFFFFFF),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Pendente de Perfil',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        );
                        if (isMobile) {
                          return Column(
                            children: [
                              avatar,
                              const SizedBox(height: 14),
                              details,
                            ],
                          );
                        }
                        return Row(
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
              // Conclusão de Perfil
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD4E3FC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_ind_rounded,
                          color: Color(0xFF3579E8),
                          size: 28,
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Complete seu cadastro',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF245FB8),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vincule um perfil de estudante ou professor para desbloquear recursos completos de turmas e idiomas.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _openStudentSignup(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3579E8),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.school_rounded, size: 18),
                          label: Text('Estudante'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _openTeacherSignup(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7651C8),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.co_present_rounded, size: 18),
                          label: Text('Professor'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingProfileCard extends StatelessWidget {
  const _PendingProfileCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: .06),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
