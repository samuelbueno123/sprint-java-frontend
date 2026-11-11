import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/dashboard/domain/entities/dashboard_data.dart';
import 'teacher_student_notes_dialog.dart';

class TeacherClassAnalyticsView extends StatefulWidget {
  const TeacherClassAnalyticsView({
    super.key,
    required this.data,
    required this.onBack,
  });

  final DashboardData data;
  final VoidCallback onBack;

  @override
  State<TeacherClassAnalyticsView> createState() =>
      _TeacherClassAnalyticsViewState();
}

class _TeacherClassAnalyticsViewState extends State<TeacherClassAnalyticsView> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _loadFuture;

  int? _selectedClassId;
  Map<String, dynamic>? _analyticsData;

  @override
  void initState() {
    super.initState();
    final assignments = widget.data.teacherAssignments
        .where((a) => a.isActive && a.schoolClassId != null)
        .toList();
    if (assignments.isNotEmpty) {
      _selectedClassId = assignments.first.schoolClassId;
    }
    _loadFuture = _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    if (_selectedClassId == null) return;
    try {
      final res = await _dio.get('/api/classes/$_selectedClassId/analytics');
      if (mounted) {
        setState(() {
          _analyticsData = Map<String, dynamic>.from(res.data ?? {});
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar analytics da turma: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignments = widget.data.teacherAssignments
        .where((a) => a.isActive && a.schoolClassId != null)
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Analytics Pedagógico da Turma'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
      ),
      body: assignments.isEmpty
          ? const Center(
              child: Text('Nenhuma turma associada a este professor.'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Class Selector
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          color: Color(0xFF7651C8),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Turma: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedClassId,
                              isExpanded: true,
                              items: assignments.map((a) {
                                return DropdownMenuItem<int>(
                                  value: a.schoolClassId,
                                  child: Text(a.schoolClassName),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedClassId = val;
                                    _loadFuture = _fetchAnalytics();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Analytics Content
                FutureBuilder(
                  future: _loadFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (_analyticsData == null) {
                      return const Center(
                        child: Text('Dados não disponíveis para esta turma.'),
                      );
                    }

                    final totalStudents =
                        _analyticsData!['totalStudents'] as int? ?? 0;
                    final activeStudents =
                        _analyticsData!['activeStudentsPastWeek'] as int? ?? 0;
                    final accuracy =
                        (_analyticsData!['averageAccuracyPercent'] as num?)
                            ?.toDouble() ??
                        0.0;
                    final totalSubmissions =
                        _analyticsData!['totalSubmissions'] as int? ?? 0;
                    final atRisk = List<Map<String, dynamic>>.from(
                      _analyticsData!['studentsNeedingAttention'] ?? [],
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KPI Grid
                        GridView.count(
                          crossAxisCount: MediaQuery.sizeOf(context).width > 600
                              ? 4
                              : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          children: [
                            _buildKpiCard(
                              title: 'Total de Alunos',
                              value: '$totalStudents',
                              icon: Icons.people_alt_rounded,
                              color: const Color(0xFF3579E8),
                            ),
                            _buildKpiCard(
                              title: 'Ativos nos Últimos 7d',
                              value: '$activeStudents',
                              icon: Icons.trending_up_rounded,
                              color: const Color(0xFF16A34A),
                            ),
                            _buildKpiCard(
                              title: 'Precisão Média',
                              value: '${accuracy.toStringAsFixed(1)}%',
                              icon: Icons.check_circle_outline_rounded,
                              color: accuracy >= 70
                                  ? const Color(0xFF16A34A)
                                  : Colors.orange.shade800,
                            ),
                            _buildKpiCard(
                              title: 'Entregas Feitas',
                              value: '$totalSubmissions',
                              icon: Icons.assignment_turned_in_rounded,
                              color: const Color(0xFF7651C8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Risk Alerts Section
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Alunos que Precisam de Atenção (${atRisk.length})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (atRisk.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF16A34A),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Excelente! Nenhum aluno com pendência crítica ou baixo rendimento detectado nesta turma.',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...atRisk.map((student) {
                            final name =
                                student['studentName'] as String? ??
                                'Estudante';
                            final sId = student['studentId'] as int? ?? 0;
                            final reason =
                                student['riskReason'] as String? ?? '';
                            final avg =
                                (student['averageAccuracy'] as num?)
                                    ?.toDouble() ??
                                0.0;
                            final daysInactive =
                                student['daysInactive'] as int? ?? 0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red.withValues(
                                    alpha: 0.15,
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reason,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Precisão: ${avg.toStringAsFixed(1)}% | Inativo há $daysInactive dia(s)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.note_add_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Anotações'),
                                  onPressed: () {
                                    TeacherStudentNotesDialog.show(
                                      context,
                                      studentId: sId,
                                      studentName: name,
                                      classId: _selectedClassId,
                                    );
                                  },
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
