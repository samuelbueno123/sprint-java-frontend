import 'package:flutter/material.dart';

import '../../domain/entities/user_profile_type.dart';

class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({
    super.key,
    required this.profileType,
    required this.activeSection,
    required this.onSectionSelected,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  final UserProfileType profileType;
  final String activeSection;
  final ValueChanged<String> onSectionSelected;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  Color get _accentColor {
    switch (profileType) {
      case UserProfileType.student:
        return const Color(0xFF3579E8);
      case UserProfileType.teacher:
        return const Color(0xFF7651C8);
      case UserProfileType.user:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 72 : 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Meu Perfil',
            isSelected: activeSection == 'profile',
            accentColor: _accentColor,
            isCollapsed: isCollapsed,
            onTap: () => onSectionSelected('profile'),
          ),
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Início',
            isSelected: activeSection == 'home',
            accentColor: _accentColor,
            isCollapsed: isCollapsed,
            onTap: () => onSectionSelected('home'),
          ),
          if (profileType != UserProfileType.user)
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
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Configurações',
            isSelected: activeSection == 'settings',
            accentColor: _accentColor,
            isCollapsed: isCollapsed,
            onTap: () => onSectionSelected('settings'),
          ),
          const Spacer(),
          if (onToggleCollapse != null) ...[
            const Divider(height: 1, color: Color(0xFFE5E8EF)),
            InkWell(
              onTap: onToggleCollapse,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: isCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.end,
                  children: [
                    if (!isCollapsed)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text(
                          'Recolher menu',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF73788B),
                          ),
                        ),
                      ),
                    Icon(
                      isCollapsed
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      color: const Color(0xFF73788B),
                      size: 22,
                    ),
                    if (!isCollapsed) const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
        ],
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
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final bool isCollapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget itemContent = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 0 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: isCollapsed
          ? Center(
              child: Icon(
                icon,
                color: isSelected ? accentColor : Colors.grey.shade600,
                size: 22,
              ),
            )
          : Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? accentColor : Colors.grey.shade600,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? accentColor : Colors.grey.shade800,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    if (isCollapsed) {
      itemContent = Tooltip(
        message: label,
        child: itemContent,
      );
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
