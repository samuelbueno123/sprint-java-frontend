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
    this.onMenuPressed,
    this.isDesktop = true,
  });

  final DashboardData data;
  final VoidCallback onLogout;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onMenuPressed;
  final bool isDesktop;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  Color get _roleColor {
    switch (data.profileType) {
      case UserProfileType.student:
        return const Color(0xFF3579E8);
      case UserProfileType.teacher:
        return const Color(0xFF7651C8);
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

    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(width: 8),
          const Text(
            'Duolinfo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const Spacer(), // Empurra TODO o bloco de perfil e conta para o canto direito!
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data.profileType == UserProfileType.student
                      ? Icons.school_rounded
                      : data.profileType == UserProfileType.teacher
                      ? Icons.co_present_rounded
                      : Icons.person_rounded,
                  size: 15,
                  color: _roleColor,
                ),
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
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(avatarUrl),
                if (isDesktop) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      data.user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down_rounded, size: 18),
                ],
              ],
            ),
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
}
