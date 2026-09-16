import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import 'dashboard_empty_state.dart';
import 'info_stat_card.dart';
import 'language_progress_card.dart';

class StudentDashboardView extends StatelessWidget {
  const StudentDashboardView({
    super.key,
    required this.data,
    required this.activeSection,
  });

  final DashboardData data;
  final String activeSection;

  static const studentGreen = Color(0xFF58CC02);

  @override
  Widget build(BuildContext context) {
    final student = data.studentProfile;
    final totalScore = student?.totalScore ?? 0;
    final languages = student?.languages ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF58CC02), Color(0xFF46A302)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: studentGreen.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, ${data.user.name.split(' ').first}! 👋',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bem-vindo(a) ao seu painel de aprendizado Duolinfo. Continue praticando para acumular pontos!',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xE6FFFFFF),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Profile Incomplete Notice
          if (!data.profileCompleted) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Seu perfil ainda precisa ser totalmente preenchido com suas preferências de idioma.',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Key Stats Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                children: [
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'PONTUAÇÃO TOTAL',
                      value: '$totalScore XP',
                      icon: Icons.stars_rounded,
                      accentColor: studentGreen,
                      subtitle: 'Soma de todos os idiomas',
                    ),
                  ),
                  SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 12),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'IDIOMAS EM ESTUDO',
                      value: '${languages.length}',
                      icon: Icons.language_rounded,
                      accentColor: const Color(0xFF1CB0F6),
                      subtitle: 'Cadastrados no seu perfil',
                    ),
                  ),
                  SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 12),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'SITUAÇÃO DO PERFIL',
                      value: data.profileCompleted ? 'Concluído' : 'Incompleto',
                      icon: data.profileCompleted
                          ? Icons.check_circle_rounded
                          : Icons.pending_rounded,
                      accentColor: data.profileCompleted
                          ? Colors.green
                          : Colors.orange,
                      subtitle: 'Validação no backend',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Main Section: Meus Idiomas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Meus Idiomas em Estudo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (languages.isNotEmpty)
                Text(
                  '${languages.length} idioma(s)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (languages.isEmpty)
            const DashboardEmptyState(
              icon: Icons.translate_rounded,
              title: 'Nenhum idioma registrado',
              message:
                  'Você ainda não possui idiomas cadastrados no seu perfil de estudante.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900
                    ? 2
                    : constraints.maxWidth > 600
                    ? 2
                    : 1;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 170,
                  ),
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    return LanguageProgressCard(language: languages[index]);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
