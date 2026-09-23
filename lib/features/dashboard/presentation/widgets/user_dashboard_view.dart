import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';

class UserDashboardView extends StatelessWidget {
  const UserDashboardView({
    super.key,
    required this.data,
    required this.activeSection,
  });

  final DashboardData data;
  final String activeSection;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5869D8), Color(0xFF7651C8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Bem-vindo, ${data.user.name.split(' ').first}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta conta está autenticada, mas não possui um perfil de estudante ou professor associado.',
                    style: TextStyle(color: Color(0xEFFFFFFF), height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE5E8EF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeSection == 'profile'
                          ? 'Meu perfil'
                          : 'Conta autenticada',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF252A3D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.user.name,
                      style: const TextStyle(
                        color: Color(0xFF252A3D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.user.email,
                      style: const TextStyle(color: Color(0xFF73788B)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
