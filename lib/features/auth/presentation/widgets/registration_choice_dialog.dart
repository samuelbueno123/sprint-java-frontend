import 'package:flutter/material.dart';

import '../pages/student_signup_page.dart';
import '../pages/teacher_signup_page.dart';

/// Floating modal dialog shown to new users (especially after Google Login)
/// requesting account type selection (Student or Teacher).
class RegistrationChoiceDialog extends StatelessWidget {
  const RegistrationChoiceDialog({
    super.key,
    this.initialEmail,
    this.initialName,
  });

  final String? initialEmail;
  final String? initialName;

  static Future<void> show(
    BuildContext context, {
    String? initialEmail,
    String? initialName,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => RegistrationChoiceDialog(
        initialEmail: initialEmail,
        initialName: initialName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 12,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5869D8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Color(0xFF5869D8),
                      size: 24,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Complete seu cadastro',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                initialName != null && initialName!.isNotEmpty
                    ? 'Olá, $initialName! Escolha como você vai usar o Duolinfo:'
                    : 'Escolha o seu tipo de conta para continuar no Duolinfo:',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF73788B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              _ChoiceCard(
                title: 'Sou Estudante',
                description:
                    'Cadastre os idiomas que deseja aprender e acompanhe seu nível.',
                icon: Icons.school_rounded,
                color: const Color(0xFF3579E8),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudentSignupPage(
                        initialEmail: initialEmail,
                        initialName: initialName,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _ChoiceCard(
                title: 'Sou Professor',
                description:
                    'Vincule sua instituição, turmas, idiomas lecionados e currículo.',
                icon: Icons.co_present_rounded,
                color: const Color(0xFF7651C8),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TeacherSignupPage(
                        initialEmail: initialEmail,
                        initialName: initialName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
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
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
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
                      style: TextStyle(
                        color: Color(0xFF73788B),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
