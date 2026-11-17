import 'package:flutter/material.dart';

import '../../../../core/ui/mascot/mascot.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/pages/login_page.dart';

class AccessSelectionPage extends StatelessWidget {
  const AccessSelectionPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MascotSprite(
                  state: MascotState.idle,
                  size: 104,
                  glowColor: Color(0xFF58CC02),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Duolinfo',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Escolha como deseja acessar a plataforma.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                _AccessButton(
                  label: 'ENTRAR COMO ALUNO',
                  color: const Color(0xFF58CC02),
                  icon: Icons.school_rounded,
                  mascotState: MascotState.celebrate,
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
                  mascotState: MascotState.intense,
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
  }
}

class _AccessButton extends StatelessWidget {
  const _AccessButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.mascotState,
    required this.onPressed,
  });
  final String label;
  final Color color;
  final IconData icon;
  final MascotState mascotState;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 58,
    child: FilledButton(
      style: FilledButton.styleFrom(backgroundColor: color),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MascotPoseEmblem(state: mascotState, size: 30),
          const SizedBox(width: 10),
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    ),
  );
}
