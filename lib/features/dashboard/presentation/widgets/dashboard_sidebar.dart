import 'package:flutter/material.dart';

import '../../domain/entities/user_profile_type.dart';

class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({
    super.key,
    required this.profileType,
    required this.activeSection,
    required this.onSectionSelected,
    this.isCollapsed = false,
    this.isSuperAdmin = false,
    this.unreadNotificationsCount = 0,
  });

  final UserProfileType profileType;
  final String activeSection;
  final ValueChanged<String> onSectionSelected;
  final bool isCollapsed;
  final bool isSuperAdmin;
  final int unreadNotificationsCount;

  Color get _accentColor {
    switch (profileType) {
      case UserProfileType.student:
        return const Color(0xFF3579E8);
      case UserProfileType.teacher:
        return const Color(0xFF7651C8);
      case UserProfileType.admin:
        return const Color(0xFFD97706);
      case UserProfileType.user:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isCollapsed ? 72 : 240,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: ClipRect(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _NavItem(
                icon: profileType == UserProfileType.admin
                    ? Icons.dashboard_customize_rounded
                    : Icons.person_outline_rounded,
                label: profileType == UserProfileType.admin
                    ? (isSuperAdmin ? 'Painel Geral' : 'Painel da Instituição')
                    : 'Início',
                isSelected: activeSection == 'profile',
                accentColor: _accentColor,
                isCollapsed: isCollapsed,
                onTap: () => onSectionSelected('profile'),
              ),
              if (profileType == UserProfileType.admin) ...[
                _NavItem(
                  icon: unreadNotificationsCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  label: 'Notificações',
                  badgeCount: unreadNotificationsCount,
                  isSelected: activeSection == 'notifications',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('notifications'),
                ),
                _NavItem(
                  icon: Icons.account_balance_rounded,
                  label: 'Dashboard Instituição',
                  isSelected: activeSection == 'institutionDashboard',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('institutionDashboard'),
                ),
                _NavItem(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Cadastros Rápidos',
                  isSelected: activeSection == 'tools',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('tools'),
                ),
                if (isSuperAdmin) ...[
                  _NavItem(
                    icon: Icons.manage_accounts_rounded,
                    label: 'Admins de Instituição',
                    isSelected: activeSection == 'institutionAdmins',
                    accentColor: _accentColor,
                    isCollapsed: isCollapsed,
                    onTap: () => onSectionSelected('institutionAdmins'),
                  ),
                  _NavItem(
                    icon: Icons.emoji_events_rounded,
                    label: 'Conquistas de Alunos',
                    isSelected: activeSection == 'studentAchievements',
                    accentColor: _accentColor,
                    isCollapsed: isCollapsed,
                    onTap: () => onSectionSelected('studentAchievements'),
                  ),
                  _NavItem(
                    icon: Icons.storage_rounded,
                    label: 'Tabelas do Banco',
                    isSelected: activeSection == 'database',
                    accentColor: _accentColor,
                    isCollapsed: isCollapsed,
                    onTap: () => onSectionSelected('database'),
                  ),
                ],
                _NavItem(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Usuários & ADMs',
                  isSelected: activeSection == 'users',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('users'),
                ),
              ],
              if (profileType != UserProfileType.user &&
                  profileType != UserProfileType.admin)
                _NavItem(
                  icon: profileType == UserProfileType.teacher
                      ? Icons.menu_book_rounded
                      : Icons.language_rounded,
                  label: profileType == UserProfileType.teacher
                      ? 'Ensino & Idiomas'
                      : 'Meus Idiomas',
                  isSelected: activeSection == 'languages',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('languages'),
                ),
              if (profileType == UserProfileType.student) ...[
                _NavItem(
                  icon: Icons.groups_rounded,
                  label: 'Minhas Turmas',
                  isSelected: activeSection == 'classes',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('classes'),
                ),
                _NavItem(
                  icon: Icons.people_alt_rounded,
                  label: 'Membros da Instituição',
                  isSelected: activeSection == 'members',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('members'),
                ),
              ],
              if (profileType == UserProfileType.teacher)
                _NavItem(
                  icon: Icons.class_rounded,
                  label: 'Gestão de Turmas',
                  isSelected: activeSection == 'classes',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('classes'),
                ),
              if (profileType == UserProfileType.teacher) ...[
                _NavItem(
                  icon: Icons.library_books_outlined,
                  label: 'Minhas atividades',
                  isSelected: activeSection == 'manageExercises',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('manageExercises'),
                ),
                _NavItem(
                  icon: Icons.post_add_rounded,
                  label: 'Criar atividade',
                  isSelected: activeSection == 'createExercise',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('createExercise'),
                ),
                _NavItem(
                  icon: Icons.fact_check_outlined,
                  label: 'Analisar respostas',
                  isSelected: activeSection == 'reviewExercises',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('reviewExercises'),
                ),
                _NavItem(
                  icon: Icons.leaderboard_rounded,
                  label: 'Desempenho',
                  isSelected: activeSection == 'teacherRanking',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('teacherRanking'),
                ),
              ],
              if (profileType == UserProfileType.student)
                _NavItem(
                  icon: Icons.school_rounded,
                  label: 'Praticar lição',
                  isSelected: activeSection == 'lesson',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('lesson'),
                ),
              if (profileType == UserProfileType.student) ...[
                _NavItem(
                  icon: Icons.history_rounded,
                  label: 'Histórico',
                  isSelected: activeSection == 'history',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('history'),
                ),
                _NavItem(
                  icon: Icons.emoji_events_outlined,
                  label: 'Conquistas',
                  isSelected: activeSection == 'achievements',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('achievements'),
                ),
                _NavItem(
                  icon: Icons.leaderboard_rounded,
                  label: 'Ranking',
                  isSelected: activeSection == 'ranking',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('ranking'),
                ),
                _NavItem(
                  icon: Icons.groups_2_outlined,
                  label: 'Ranking de grupos',
                  isSelected: activeSection == 'groupRanking',
                  accentColor: _accentColor,
                  isCollapsed: isCollapsed,
                  onTap: () => onSectionSelected('groupRanking'),
                ),
              ],
              _NavItem(
                icon: Icons.settings_rounded,
                label: 'Configurações',
                isSelected: activeSection == 'settings',
                accentColor: _accentColor,
                isCollapsed: isCollapsed,
                onTap: () => onSectionSelected('settings'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.isCollapsed,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final bool isCollapsed;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedIconColor = isDark ? Colors.white70 : Colors.grey.shade600;
    final unselectedTextColor = isDark ? Colors.white : Colors.grey.shade800;

    Widget iconWidget = Icon(
      icon,
      color: isSelected ? accentColor : unselectedIconColor,
      size: 22,
    );

    if (badgeCount > 0) {
      iconWidget = Badge(
        backgroundColor: Colors.redAccent,
        label: Text(
          badgeCount > 99 ? '99+' : '$badgeCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: iconWidget,
      );
    }

    Widget itemContent = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor.withValues(alpha: isDark ? 0.24 : 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showText = !isCollapsed && constraints.maxWidth > 100;
          return Row(
            mainAxisAlignment: showText
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              iconWidget,
              if (showText) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? accentColor : unselectedTextColor,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );

    if (isCollapsed) {
      itemContent = Tooltip(message: label, child: itemContent);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: itemContent,
      ),
    );
  }
}
