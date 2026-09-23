import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/user_profile_type.dart';

class DashboardTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardTopBar({
    super.key,
    required this.data,
    required this.onLogout,
    this.onMenuPressed,
    this.isDesktop = true,
  });

  final DashboardData data;
  final VoidCallback onLogout;
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
    final initial = data.user.name.isNotEmpty
        ? data.user.name[0].toUpperCase()
        : 'U';

    Widget fallback() => Center(
      child: Text(
        initial,
        style: TextStyle(color: _roleColor, fontWeight: FontWeight.bold),
      ),
    );

    return ClipOval(
      child: Container(
        width: 36,
        height: 36,
        color: _roleColor.withValues(alpha: 0.2),
        child: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? Image.network(
                avatarUrl,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback(),
              )
            : fallback(),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (!isDesktop && onMenuPressed != null) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: onMenuPressed,
            ),
            const SizedBox(width: 8),
          ],
          const Icon(
            Icons.menu_book_rounded,
            color: Color(0xFF58CC02),
            size: 28,
          ),
          const SizedBox(width: 10),
          const Text(
            'Duolinfo',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  size: 16,
                  color: _roleColor,
                ),
                const SizedBox(width: 6),
                Text(
                  data.profileType.label,
                  style: TextStyle(
                    color: _roleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildAvatar(avatarUrl),
                if (isDesktop) ...[
                  const SizedBox(width: 10),
                  Text(
                    data.user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded, size: 20),
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
