import 'package:flutter/material.dart';

import 'login_page.dart';
import '../widgets/auth_page_frame.dart';
import 'student_signup_page.dart';
import 'teacher_signup_page.dart';

class RegistrationChoicePage extends StatelessWidget {
  const RegistrationChoicePage({
    super.key,
    this.initialEmail,
    this.initialName,
  });

  final String? initialEmail;
  final String? initialName;

  @override
  Widget build(BuildContext context) => AuthPageFrame(
    title: 'Criar perfil',
    subtitle: 'Escolha como você vai usar o Duolinfo.',
    accentColor: const Color(0xFF5869D8),
    onBack: () => _openLogin(context),
    child: Column(
      children: [
        _RoleCard(
          title: 'Sou estudante',
          description: 'Cadastre os idiomas que deseja estudar.',
          icon: Icons.school_rounded,
          color: const Color(0xFF3579E8),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentSignupPage(
                initialEmail: initialEmail,
                initialName: initialName,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          title: 'Sou professor',
          description: 'Informe sua instituição e as áreas que leciona.',
          icon: Icons.co_present_rounded,
          color: const Color(0xFF7651C8),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TeacherSignupPage(
                initialEmail: initialEmail,
                initialName: initialName,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: () => _openLogin(context),
          child: const Text('Já tem perfil? Entrar'),
        ),
      ],
    ),
  );

  void _openLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
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
    color: color.withValues(alpha: .055),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF73788B),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    ),
  );
}
