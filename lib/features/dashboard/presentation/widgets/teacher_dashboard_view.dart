import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import 'dashboard_empty_state.dart';
import 'info_stat_card.dart';
import 'teacher_document_tile.dart';

class TeacherDashboardView extends StatelessWidget {
  const TeacherDashboardView({
    super.key,
    required this.data,
    required this.activeSection,
  });

  final DashboardData data;
  final String activeSection;

  static const teacherBlue = Color(0xFF1CB0F6);

  @override
  Widget build(BuildContext context) {
    final teacher = data.teacherProfile;
    final institution = teacher?.institution ?? 'Não informada';
    final taughtLangs = teacher?.taughtLanguages ?? const [];
    final specs = teacher?.specializationAreas ?? const [];
    final docs = teacher?.documents ?? const [];

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
                colors: [Color(0xFF1CB0F6), Color(0xFF0288D1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: teacherBlue.withValues(alpha: 0.25),
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
                        'Prof. ${data.user.name} 👋',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        institution.isNotEmpty
                            ? 'Painel docente no Duolinfo • $institution'
                            : 'Painel docente no Duolinfo.',
                        style: const TextStyle(
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
                    Icons.co_present_rounded,
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
                      'Seu cadastro docente requer informações de instituição e idiomas lecionados para ficar 100% completo.',
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

          // Stats Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                children: [
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'INSTITUIÇÃO',
                      value: institution.isNotEmpty ? institution : 'Pendente',
                      icon: Icons.account_balance_rounded,
                      accentColor: teacherBlue,
                    ),
                  ),
                  SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 12),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'IDIOMAS LECIONADOS',
                      value: '${taughtLangs.length}',
                      icon: Icons.translate_rounded,
                      accentColor: const Color(0xFF58CC02),
                      subtitle: taughtLangs.isNotEmpty
                          ? taughtLangs.join(', ')
                          : 'Nenhum cadastrado',
                    ),
                  ),
                  SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 12),
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: InfoStatCard(
                      title: 'DOCUMENTOS',
                      value: '${docs.length}',
                      icon: Icons.folder_shared_rounded,
                      accentColor: Colors.deepPurple,
                      subtitle: 'Comprovação acadêmica',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Taught Languages & Specialization Areas Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Taught Languages Card
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: _SectionCard(
                      title: 'Idiomas Lecionados',
                      icon: Icons.record_voice_over_rounded,
                      accentColor: teacherBlue,
                      child: taughtLangs.isEmpty
                          ? const Text(
                              'Nenhum idioma cadastrado.',
                              style: TextStyle(color: Colors.grey),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: taughtLangs
                                  .map(
                                    (lang) => Chip(
                                      avatar: const Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: teacherBlue,
                                      ),
                                      label: Text(
                                        lang,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: teacherBlue.withValues(
                                        alpha: 0.12,
                                      ),
                                      side: BorderSide.none,
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ),
                  SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),

                  // Specialization Areas Card
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: _SectionCard(
                      title: 'Áreas de Especialização',
                      icon: Icons.workspace_premium_rounded,
                      accentColor: Colors.orange,
                      child: specs.isEmpty
                          ? const Text(
                              'Nenhuma área de especialização registrada.',
                              style: TextStyle(color: Colors.grey),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: specs
                                  .map(
                                    (spec) => Chip(
                                      avatar: const Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                      label: Text(
                                        spec,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: Colors.orange.withValues(
                                        alpha: 0.12,
                                      ),
                                      side: BorderSide.none,
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Bibliography Section
          if (teacher?.bibliography != null &&
              teacher!.bibliography!.isNotEmpty) ...[
            _SectionCard(
              title: 'Bibliografia & Resumo Profissional',
              icon: Icons.menu_book_rounded,
              accentColor: Colors.indigo,
              child: Text(
                teacher.bibliography!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Documents List
          const Text(
            'Documentos Registrados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          if (docs.isEmpty)
            const DashboardEmptyState(
              icon: Icons.folder_open_rounded,
              title: 'Nenhum documento anexado',
              message:
                  'Não há comprovantes acadêmicos ou diplomas vinculados a este perfil.',
            )
          else
            Column(
              children: docs
                  .map((doc) => TeacherDocumentTile(document: doc))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
