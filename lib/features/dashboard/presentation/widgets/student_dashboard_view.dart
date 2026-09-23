import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/student_enrollment.dart';
import 'dashboard_empty_state.dart';

class StudentDashboardView extends StatelessWidget {
  const StudentDashboardView({
    super.key,
    required this.data,
    required this.activeSection,
  });

  final DashboardData data;
  final String activeSection;

  static const _blue = Color(0xFF3579E8);

  @override
  Widget build(BuildContext context) {
    final student = data.studentProfile;
    final name = student?.name.isNotEmpty == true
        ? student!.name
        : data.user.name;
    final languages = student?.languages ?? const [];

    if (activeSection == 'languages') {
      return _page(
        title: 'Meus idiomas',
        subtitle: 'Idiomas vinculados ao seu perfil de estudante.',
        child: _languageContent(languages),
      );
    }
    if (activeSection == 'profile') {
      return _page(
        title: 'Meu perfil',
        subtitle: 'Dados cadastrados na sua conta de estudante.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileCard(
              icon: Icons.person_outline_rounded,
              title: 'Dados da conta',
              children: [
                _DetailRow(label: 'Nome', value: name),
                _DetailRow(label: 'Email', value: data.user.email),
              ],
            ),
            const SizedBox(height: 16),
            _ProfileCard(
              icon: Icons.translate_rounded,
              title: 'Idiomas de interesse',
              children: [_languageContent(languages)],
            ),
            const SizedBox(height: 16),
            _ProfileCard(
              icon: Icons.groups_rounded,
              title: 'Turmas ativas',
              children: [_enrollmentContent(data.studentEnrollments)],
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeBanner(
            name: name,
            subtitle:
                'Seu perfil de aprendizado começa com os idiomas que você escolheu.',
          ),
          const SizedBox(height: 22),
          _ProfileCard(
            icon: Icons.translate_rounded,
            title: 'Idiomas no seu perfil',
            children: [_languageContent(languages)],
          ),
          const SizedBox(height: 16),
          _ProfileCard(
            icon: Icons.person_outline_rounded,
            title: 'Conta de estudante',
            children: [
              _DetailRow(label: 'Nome', value: name),
              _DetailRow(label: 'Email', value: data.user.email),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileCard(
            icon: Icons.groups_rounded,
            title: 'Turmas ativas',
            children: [_enrollmentContent(data.studentEnrollments)],
          ),
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

  Widget _languageContent(List<String> languages) {
    if (languages.isEmpty) {
      return const DashboardEmptyState(
        icon: Icons.translate_rounded,
        title: 'Nenhum idioma cadastrado',
        message: 'Ainda não há idiomas vinculados a este perfil.',
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: languages.map((language) {
        final label = language;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD4E3FC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded, size: 17, color: _blue),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF245FB8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _enrollmentContent(List<StudentEnrollment> enrollments) {
    if (enrollments.isEmpty) {
      return const Text(
        'Nenhuma matrícula ativa vinculada ao perfil.',
        style: TextStyle(color: Color(0xFF73788B)),
      );
    }
    return Column(
      children: enrollments
          .map(
            (enrollment) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6EAF2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: _blue, size: 21),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enrollment.schoolClassName,
                            style: const TextStyle(
                              color: Color(0xFF252A3D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (enrollment.enrollmentDate.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Matrícula em ${enrollment.enrollmentDate}',
                              style: const TextStyle(
                                color: Color(0xFF73788B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF32946B),
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF4D8CEF), Color(0xFF3570D5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF3579E8).withValues(alpha: .18),
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
                subtitle,
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
            Icons.school_rounded,
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
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

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
              Icon(icon, color: StudentDashboardView._blue, size: 21),
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
          ...children,
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
          width: 82,
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
