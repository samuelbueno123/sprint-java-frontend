import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import 'info_stat_card.dart';

class UserDashboardView extends StatelessWidget {
  const UserDashboardView({
    super.key,
    required this.data,
    required this.activeSection,
  });

  final DashboardData data;
  final String activeSection;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bem-vindo(a), ${data.user.name.split(' ').first}! 👋',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sua conta está autenticada com sucesso no Duolinfo.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xE6FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.person_pin_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Setup Profile Action Notice
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, color: Colors.blue.shade800, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conclua a Seleção de Perfil',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sua conta no momento possui perfil geral de usuário. Escolha se deseja cadastrar-se como Aluno ou Professor para acessar todos os recursos.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // User Info Card
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                children: [
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'CONTA AUTENTICADA',
                      value: data.user.email,
                      icon: Icons.mark_email_read_rounded,
                      accentColor: Colors.blue,
                    ),
                  ),
                  SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 12),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'SITUAÇÃO DO PERFIL',
                      value: 'Usuário Geral',
                      icon: Icons.pending_rounded,
                      accentColor: Colors.orange,
                      subtitle: 'Selecione Aluno ou Professor',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
