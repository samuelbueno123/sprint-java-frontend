import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/teacher_class_assignment.dart';
import '../../domain/entities/teacher_profile.dart';
import 'dashboard_empty_state.dart';

class TeacherDashboardView extends StatelessWidget {
  const TeacherDashboardView({
    super.key,
    required this.data,
    required this.activeSection,
  });

  final DashboardData data;
  final String activeSection;

  static const _purple = Color(0xFF7651C8);

  @override
  Widget build(BuildContext context) {
    final teacher = data.teacherProfile;
    if (teacher == null) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: DashboardEmptyState(
          icon: Icons.co_present_rounded,
          title: 'Perfil docente indisponível',
          message:
              'Não foi possível localizar os dados de professor desta conta.',
        ),
      );
    }

    if (activeSection == 'languages') {
      return _page(
        title: 'Ensino e idiomas',
        subtitle: 'Idiomas e áreas de especialização do seu perfil.',
        child: Column(
          children: [
            _ProfileCard(
              icon: Icons.record_voice_over_rounded,
              title: 'Idiomas lecionados',
              child: _tagList(teacher.taughtLanguages, _purple),
            ),
            const SizedBox(height: 16),
            _ProfileCard(
              icon: Icons.workspace_premium_outlined,
              title: 'Áreas de especialização',
              child: _tagList(
                teacher.specializationAreas,
                const Color(0xFFE5902D),
              ),
            ),
          ],
        ),
      );
    }

    if (activeSection == 'profile') {
      return _page(
        title: 'Meu perfil',
        subtitle: 'Dados profissionais cadastrados no Duolinfo.',
        child: _profileContent(teacher),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeBanner(name: teacher.name, institution: teacher.institution),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 620;
              return Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: wide ? 1 : 0,
                    fit: wide ? FlexFit.tight : FlexFit.loose,
                    child: _ProfileCard(
                      icon: Icons.translate_rounded,
                      title: 'Idiomas lecionados',
                      child: _tagList(teacher.taughtLanguages, _purple),
                    ),
                  ),
                  SizedBox(width: wide ? 14 : 0, height: wide ? 0 : 14),
                  Flexible(
                    flex: wide ? 1 : 0,
                    fit: wide ? FlexFit.tight : FlexFit.loose,
                    child: _ProfileCard(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Especializações',
                      child: _tagList(
                        teacher.specializationAreas,
                        const Color(0xFFE5902D),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _profileContent(teacher),
        ],
      ),
    );
  }

  Widget _page({
    required String title,
    required String subtitle,
    required Widget child,
  }) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF20243A),
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Color(0xFF73788B))),
        const SizedBox(height: 22),
        child,
      ],
    ),
  );

  Widget _profileContent(TeacherProfile teacher) => Column(
    children: [
      _ProfileCard(
        icon: Icons.person_outline_rounded,
        title: 'Dados profissionais',
        child: Column(
          children: [
            _DetailRow(label: 'Nome', value: teacher.name),
            _DetailRow(label: 'Email', value: teacher.email),
            _DetailRow(label: 'Instituição', value: teacher.institution),
          ],
        ),
      ),
      if (teacher.bibliography?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 16),
        _ProfileCard(
          icon: Icons.menu_book_rounded,
          title: 'Biografia profissional',
          child: Text(
            teacher.bibliography!,
            style: const TextStyle(color: Color(0xFF4D5365), height: 1.55),
          ),
        ),
      ],
      const SizedBox(height: 16),
      _ProfileCard(
        icon: Icons.groups_rounded,
        title: 'Histórico de turmas',
        child: _assignmentContent(data.teacherAssignments),
      ),
    ],
  );

  Widget _assignmentContent(List<TeacherClassAssignment> assignments) {
    if (assignments.isEmpty) {
      return const Text(
        'Nenhuma turma vinculada ao perfil.',
        style: TextStyle(color: Color(0xFF73788B)),
      );
    }
    return Column(
      children: assignments
          .map(
            (assignment) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEAE6F3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      color: assignment.isActive
                          ? _purple
                          : const Color(0xFF9296A5),
                      size: 21,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.schoolClassName,
                            style: const TextStyle(
                              color: Color(0xFF252A3D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            assignment.isActive
                                ? 'Ativa desde ${assignment.startDate}'
                                : 'Período: ${assignment.startDate} – ${assignment.endDate}',
                            style: const TextStyle(
                              color: Color(0xFF73788B),
                              fontSize: 12,
                            ),
                          ),
                          if (assignment.reason?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 3),
                            Text(
                              assignment.reason!,
                              style: const TextStyle(
                                color: Color(0xFF73788B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      assignment.isActive ? 'Ativa' : 'Encerrada',
                      style: TextStyle(
                        color: assignment.isActive
                            ? const Color(0xFF32946B)
                            : const Color(0xFF73788B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _tagList(List<String> values, Color color) {
    if (values.isEmpty) {
      return const Text(
        'Nenhum dado cadastrado.',
        style: TextStyle(color: Color(0xFF73788B)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (value) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: .2)),
              ),
              child: Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.name, required this.institution});

  final String name;
  final String institution;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF805BCF), Color(0xFF6741B5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7651C8).withValues(alpha: .18),
          blurRadius: 18,
          offset: const Offset(0, 7),
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
                'Olá, ${name.split(' ').first}!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                institution.isNotEmpty
                    ? 'Seu perfil docente • $institution'
                    : 'Seu perfil docente no Duolinfo.',
                style: const TextStyle(color: Color(0xEFFFFFFF), height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.co_present_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ],
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFE5E8EF)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: TeacherDashboardView._purple, size: 21),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF252A3D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 94,
          child: Text(label, style: const TextStyle(color: Color(0xFF73788B))),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Não informado' : value,
            style: const TextStyle(
              color: Color(0xFF252A3D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
