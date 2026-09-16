import 'package:flutter/material.dart';

import '../../domain/entities/user_profile_type.dart';

class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({
    super.key,
    required this.profileType,
    required this.activeSection,
    required this.onSectionSelected,
  });

  final UserProfileType profileType;
  final String activeSection;
  final ValueChanged<String> onSectionSelected;

  Color get _accentColor {
    switch (profileType) {
      case UserProfileType.student:
        return const Color(0xFF58CC02);
      case UserProfileType.teacher:
        return const Color(0xFF1CB0F6);
      case UserProfileType.user:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Início',
            isSelected: activeSection == 'home',
            accentColor: _accentColor,
            onTap: () => onSectionSelected('home'),
          ),
          _NavItem(
            icon: profileType == UserProfileType.teacher
                ? Icons.menu_book_rounded
                : Icons.language_rounded,
            label: profileType == UserProfileType.teacher
                ? 'Ensino & Idiomas'
                : 'Meus Idiomas',
            isSelected: activeSection == 'languages',
            accentColor: _accentColor,
            onTap: () => onSectionSelected('languages'),
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Meu Perfil',
            isSelected: activeSection == 'profile',
            accentColor: _accentColor,
            onTap: () => onSectionSelected('profile'),
          ),
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? accentColor : Colors.grey.shade600,
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? accentColor : Colors.grey.shade800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
