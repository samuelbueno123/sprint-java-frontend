import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/user_profile_type.dart';
import 'app_user_avatar.dart';

class DashboardTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardTopBar({
    super.key,
    required this.data,
    required this.onLogout,
    this.onOpenSettings,
    this.onProfileTypeChanged,
    this.onOpenNotifications,
    this.onMenuPressed,
  });

  final DashboardData data;
  final VoidCallback onLogout;
  final VoidCallback? onOpenSettings;
  final ValueChanged<UserProfileType>? onProfileTypeChanged;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onMenuPressed;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  Color get _roleColor {
    switch (data.profileType) {
      case UserProfileType.student:
        return const Color(0xFF3579E8);
      case UserProfileType.teacher:
        return const Color(0xFF7651C8);
      case UserProfileType.admin:
        return const Color(0xFFD97706);
      case UserProfileType.user:
        return Colors.grey.shade700;
    }
  }

  Widget _buildAvatar(String? avatarUrl) {
    return AppUserAvatar(
      name: data.user.name,
      pictureUrl: avatarUrl,
      radius: 18,
      backgroundColor: _roleColor.withValues(alpha: 0.2),
      textColor: _roleColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = data.user.picture;
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    Widget roleIndicator = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 7 : 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: _roleColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_roleIcon(data.profileType), size: 15, color: _roleColor),
          if (!isCompact) ...[
            const SizedBox(width: 4),
            Text(
              data.profileType.label,
              style: TextStyle(
                color: _roleColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
          if (data.availableProfileTypes.length > 1) ...[
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: _roleColor),
          ],
        ],
      ),
    );
    if (data.availableProfileTypes.length > 1 && onProfileTypeChanged != null) {
      roleIndicator = PopupMenuButton<UserProfileType>(
        tooltip: 'Trocar painel',
        onSelected: onProfileTypeChanged,
        itemBuilder: (context) => data.availableProfileTypes.map((role) {
          return PopupMenuItem(
            value: role,
            child: Row(
              children: [
                Icon(_roleIcon(role), size: 18),
                const SizedBox(width: 10),
                Text('Painel ${role.label.toLowerCase()}'),
                if (role == data.profileType) ...[
                  const Spacer(),
                  const Icon(Icons.check_rounded, size: 18),
                ],
              ],
            ),
          );
        }).toList(),
        child: roleIndicator,
      );
    } else {
      roleIndicator = Tooltip(
        message: data.profileType.label,
        child: roleIndicator,
      );
    }

    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16),
      child: Row(
        children: [
          if (onMenuPressed != null) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Menu lateral',
              onPressed: onMenuPressed,
            ),
            const SizedBox(width: 4),
          ],
          const Icon(
            Icons.menu_book_rounded,
            color: Color(0xFF58CC02),
            size: 26,
          ),
          SizedBox(width: isCompact ? 5 : 8),
          const Text(
            'Duolinfo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const Spacer(), // Empurra TODO o bloco de perfil e conta para o canto direito!
          if (onOpenNotifications != null)
            IconButton(
              tooltip: 'Notificações administrativas',
              onPressed: onOpenNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          roleIndicator,
          SizedBox(width: isCompact ? 6 : 12),
          PopupMenuButton<String>(
            tooltip: 'Abrir menu do perfil',
            onSelected: (value) {
              if (value == 'settings') {
                onOpenSettings?.call();
              } else if (value == 'logout') {
                onLogout();
              }
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildAvatar(avatarUrl),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.user.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      data.user.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_rounded,
                      color: Colors.black87,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text('Configurações'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Sair da conta',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(UserProfileType role) {
    switch (role) {
      case UserProfileType.student:
        return Icons.school_rounded;
      case UserProfileType.teacher:
        return Icons.co_present_rounded;
      case UserProfileType.admin:
        return Icons.admin_panel_settings_rounded;
      case UserProfileType.user:
        return Icons.person_rounded;
    }
  }
}
