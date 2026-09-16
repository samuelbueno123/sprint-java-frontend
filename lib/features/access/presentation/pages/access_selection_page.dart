import 'package:flutter/material.dart';

import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/pages/login_page.dart';

class AccessSelectionPage extends StatelessWidget {
  const AccessSelectionPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF58CC02),
                  size: 70,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Duolinfo',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Escolha como deseja acessar a plataforma.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                _AccessButton(
                  label: 'ENTRAR COMO ALUNO',
                  color: const Color(0xFF58CC02),
                  icon: Icons.school_rounded,
                  onPressed: () => _openLogin(
                    context,
                    UserRole.student,
                    const Color(0xFF58CC02),
                    Icons.school_rounded,
                  ),
                ),
                const SizedBox(height: 18),
                _AccessButton(
                  label: 'ENTRAR COMO PROFESSOR',
                  color: const Color(0xFF1CB0F6),
                  icon: Icons.co_present_rounded,
                  onPressed: () => _openLogin(
                    context,
                    UserRole.teacher,
                    const Color(0xFF1CB0F6),
                    Icons.co_present_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  void _openLogin(
    BuildContext context,
    UserRole role,
    Color color,
    IconData icon,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginPage(role: role, primaryColor: color, icon: icon),
      ),
    );
  }
}

class _AccessButton extends StatelessWidget {
  const _AccessButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 58,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: color),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}
