import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_feedback_widgets.dart';
import '../../../../core/constants/supported_languages.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/ui/mascot/mascot.dart';
import '../../domain/entities/dashboard_data.dart';
import 'responsive_layout.dart';
import 'teacher_exercise_preview_screen.dart';

class _CloneExerciseDialog extends StatefulWidget {
  const _CloneExerciseDialog({
    required this.initialTitle,
    required this.classes,
  });

  final String initialTitle;
  final List<_ClassOption> classes;

  @override
  State<_CloneExerciseDialog> createState() => _CloneExerciseDialogState();
}

class _CloneExerciseDialogState extends State<_CloneExerciseDialog> {
  late final TextEditingController _titleCtrl;
  late int _targetClassId;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _targetClassId = widget.classes.first.id;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _validationError = 'Informe o título da nova atividade.');
      return;
    }
    Navigator.of(context).pop(<String, dynamic>{
      'targetSchoolClassId': _targetClassId,
      'newTitle': title,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clonar Atividade'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Duplique todas as questões e conteúdos desta atividade para outra turma:',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Título da Nova Atividade',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _targetClassId,
            decoration: const InputDecoration(
              labelText: 'Turma de Destino',
              isDense: true,
            ),
            items: widget.classes
                .map(
                  (c) =>
                      DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _targetClassId = val);
            },
          ),
          if (_validationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _validationError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Clonar Agora')),
      ],
    );
  }
}

class TeacherExercisesOverviewScreen extends StatefulWidget {
  const TeacherExercisesOverviewScreen({
    super.key,
    required this.data,
    required this.exercises,
    required this.submissions,
    this.dataLoadError,
    this.dio,
    required this.onCreateExercise,
    required this.onRefresh,
  });

  final DashboardData data;
  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> submissions;
  final String? dataLoadError;
  final Dio? dio;
  final VoidCallback onCreateExercise;
  final VoidCallback onRefresh;

  @override
  State<TeacherExercisesOverviewScreen> createState() =>
      _TeacherExercisesOverviewScreenState();
}

class _TeacherExercisesOverviewScreenState
    extends State<TeacherExercisesOverviewScreen> {
  late final Dio _dio = widget.dio ?? ApiClient().dio;
  final Set<String> _expandedPackages = {};
  final Map<int, Set<int>?> _studentIdsByClass = {};
  int? _selectedClassId;
  bool _loadingStudents = false;
  String? _studentLoadError;

  List<_ClassOption> get _classes {
    final names = <int, String>{};
    for (final assignment in widget.data.teacherAssignments) {
      final id = assignment.schoolClassId;
      if (id != null && assignment.schoolClassName.trim().isNotEmpty) {
        names[id] = assignment.schoolClassName;
      }
    }
    for (final exercise in widget.exercises) {
      final id = (exercise['schoolClassId'] as num?)?.toInt();
      final name = exercise['schoolClassName']?.toString().trim();
      if (id != null && name != null && name.isNotEmpty) names[id] = name;
    }
    final result =
        names.entries
            .map((entry) => _ClassOption(id: entry.key, name: entry.value))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return result;
  }

  List<Map<String, dynamic>> get _classExercises => widget.exercises
      .where(
        (exercise) =>
            (exercise['schoolClassId'] as num?)?.toInt() == _selectedClassId,
      )
      .toList();

  List<Map<String, dynamic>> _submissionsFor(int exerciseId) {
    final activeStudentIds = _studentIdsByClass[_selectedClassId];
    final latestByStudent = <String, Map<String, dynamic>>{};
    for (final submission in widget.submissions) {
      if (_int(submission['exerciseId']) != exerciseId) continue;
      final studentId = _int(submission['studentId']);
      if (activeStudentIds != null &&
          (studentId == null || !activeStudentIds.contains(studentId))) {
        continue;
      }
      final key = studentId?.toString() ?? 'submission:${submission['id']}';
      final current = latestByStudent[key];
      final submittedAt = DateTime.tryParse(
        '${submission['submittedAt'] ?? ''}',
      );
      final currentSubmittedAt = DateTime.tryParse(
        '${current?['submittedAt'] ?? ''}',
      );
      if (current == null ||
          (submittedAt != null &&
              (currentSubmittedAt == null ||
                  submittedAt.isAfter(currentSubmittedAt)))) {
        latestByStudent[key] = submission;
      }
    }
    return latestByStudent.values.toList();
  }

  @override
  void initState() {
    super.initState();
    final classes = _classes;
    if (classes.isNotEmpty) _selectedClassId = classes.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final classId = _selectedClassId;
      if (classId != null) _loadStudentCount(classId);
    });
  }

  Future<void> _loadStudentCount(int classId) async {
    if (_studentIdsByClass.containsKey(classId)) return;
    setState(() {
      _loadingStudents = true;
      _studentLoadError = null;
    });
    try {
      final response = await _dio.get('/api/students/class/$classId');
      if (!mounted || _selectedClassId != classId) return;
      final studentIds = (response.data as List)
          .map((student) => _int(student['id']))
          .whereType<int>()
          .toSet();
      setState(() => _studentIdsByClass[classId] = studentIds);
    } catch (error) {
      if (!mounted || _selectedClassId != classId) return;
      setState(() => _studentLoadError = _parseError(error));
    } finally {
      if (mounted && _selectedClassId == classId) {
        setState(() => _loadingStudents = false);
      }
    }
  }

  void _selectClass(int? classId) {
    if (classId == null || classId == _selectedClassId) return;
    setState(() {
      _selectedClassId = classId;
      _studentLoadError = null;
    });
    _loadStudentCount(classId);
  }

  @override
  Widget build(BuildContext context) {
    final classes = _classes;
    final exercises = _classExercises;
    final classSize = _studentIdsByClass[_selectedClassId]?.length;
    final allSubmissions = exercises
        .expand((exercise) => _submissionsFor(_int(exercise['id']) ?? -1))
        .toList();
    final average = _averageScore(allSubmissions);
    final activeCount = exercises.where((exercise) {
      final count = _submissionsFor(_int(exercise['id']) ?? -1).length;
      return classSize == null || classSize == 0 || count < classSize;
    }).length;
    final packages = _packages(exercises);
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: responsivePagePadding(context),
      children: [
        _header(context),
        const SizedBox(height: 20),
        if (classes.isEmpty)
          _empty(
            context,
            title: 'Nenhuma turma vinculada',
            message:
                widget.dataLoadError ??
                'Não há turmas registradas para este professor. Atualize ou vincule uma turma para acompanhar as atividades.',
            onRefresh: widget.onRefresh,
          )
        else ...[
          _classPicker(context, classes),
          const SizedBox(height: 16),
          if (_studentLoadError != null)
            _dataNotice(
              context,
              title: 'Não foi possível carregar os estudantes',
              message: _studentLoadError!,
              onRefresh: () {
                final id = _selectedClassId;
                if (id != null) {
                  _studentIdsByClass.remove(id);
                  _loadStudentCount(id);
                }
              },
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : 1;
              final cardWidth = columns == 3
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      context,
                      icon: Icons.description_outlined,
                      title: 'Total de atividades',
                      value: '${exercises.length}',
                      color: colors.primary,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      context,
                      icon: Icons.check_circle_outline,
                      title: 'Em andamento',
                      value: '$activeCount',
                      color: const Color(0xFF238A5B),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      context,
                      icon: Icons.trending_up,
                      title: 'Média das entregas',
                      value: average == null ? '—' : average.toStringAsFixed(1),
                      color: const Color(0xFF3478C8),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: responsiveCardPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Atividades da turma',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: widget.onCreateExercise,
                        icon: const Icon(Icons.add),
                        label: const Text('Novo exercício'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_classes.firstWhere((item) => item.id == _selectedClassId, orElse: () => _classes.first).name} · ${classSize == null ? (_loadingStudents ? 'Carregando estudantes…' : 'estudantes não carregados') : '$classSize estudantes'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (widget.dataLoadError != null)
                    _dataNotice(
                      context,
                      title: 'Parte dos dados não foi carregada',
                      message: widget.dataLoadError!,
                      onRefresh: widget.onRefresh,
                    ),
                  if (exercises.isEmpty)
                    _empty(
                      context,
                      title: widget.dataLoadError == null
                          ? 'Nenhuma atividade publicada'
                          : 'Atividades indisponíveis',
                      message:
                          widget.dataLoadError ??
                          'Não há atividades desta turma registradas no banco de dados. Atualize para consultar novamente.',
                      onRefresh: widget.onRefresh,
                    )
                  else
                    for (final package in packages)
                      _packageCard(context, package, classSize),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _header(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: responsiveCardPadding(context),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7651C8), Color(0xFF6841B8)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gerenciar conteúdos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Acompanhe as tarefas que você já passou para cada turma.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: widget.onCreateExercise,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: colors.onPrimary.withValues(alpha: .7),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Criar atividade'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.assignment_turned_in_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _classPicker(BuildContext context, List<_ClassOption> classes) =>
      DropdownButtonFormField<int>(
        initialValue: _selectedClassId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Turma',
          prefixIcon: Icon(Icons.groups_outlined),
          border: OutlineInputBorder(),
        ),
        items: [
          for (final item in classes)
            DropdownMenuItem(value: item.id, child: Text(item.name)),
        ],
        onChanged: _selectClass,
      );

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _packageCard(
    BuildContext context,
    _ExercisePackage package,
    int? classSize,
  ) {
    final colors = Theme.of(context).colorScheme;
    final open = _expandedPackages.contains(package.key);
    final packageSubmissions = package.exercises
        .expand((exercise) => _submissionsFor(_int(exercise['id']) ?? -1))
        .toList();
    final completedExercises = package.exercises.where((exercise) {
      final submitted = _submissionsFor(_int(exercise['id']) ?? -1).length;
      return classSize != null && classSize > 0 && submitted >= classSize;
    }).length;
    final isComplete =
        package.exercises.isNotEmpty &&
        completedExercises == package.exercises.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (open) {
                _expandedPackages.remove(package.key);
              } else {
                _expandedPackages.add(package.key);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: open ? .25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.chevron_right,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _categoryChip(context, package.category),
                            Text(
                              package.theme,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${package.exercises.length} atividades · $completedExercises concluídas · média ${_averageScore(packageSubmissions)?.toStringAsFixed(1) ?? '—'}/10',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _statusChip(context, isComplete),
                ],
              ),
            ),
          ),
          if (open)
            Container(
              width: double.infinity,
              color: colors.surfaceContainerLow,
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
              child: Column(
                children: [
                  for (final exercise in package.exercises)
                    _exerciseTile(context, exercise, classSize),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _exerciseTile(
    BuildContext context,
    Map<String, dynamic> exercise,
    int? classSize,
  ) {
    final colors = Theme.of(context).colorScheme;
    final exerciseId = _int(exercise['id']) ?? -1;
    final submissions = _submissionsFor(exerciseId);
    final questions = exercise['questions'] as List? ?? const [];
    final submitted = submissions.length;
    final average = _averageScore(submissions);
    final completion = classSize == null || classSize == 0
        ? null
        : (submitted / classSize).clamp(0.0, 1.0);
    final styles = questions
        .whereType<Map>()
        .map((question) => question['style']?.toString())
        .whereType<String>()
        .toSet();
    final styleLabel = styles.isEmpty
        ? 'Conteúdo'
        : styles.length == 1
        ? styles.first
        : 'Misto';
    final createdAt = _dateLabel(exercise['createdAt']);
    final hasMascotHelp =
        exercise['mascotHelpMessage']?.toString().trim().isNotEmpty == true;

    return Card(
      margin: const EdgeInsets.only(top: 10),
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.menu_book_outlined, size: 18, color: colors.primary),
                Text(
                  '${exercise['title'] ?? 'Atividade'}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                _statusChip(
                  context,
                  classSize != null && classSize > 0 && submitted >= classSize,
                ),
                if (hasMascotHelp)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tips_and_updates_rounded,
                          size: 13,
                          color: Color(0xFF4F46E5),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Dica do Bode',
                          style: TextStyle(
                            color: Color(0xFF4F46E5),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                _detailLabel(context, styleLabel),
                _detailLabel(context, '${questions.length} questões'),
                if (createdAt != null) _detailLabel(context, createdAt),
              ],
            ),
            const SizedBox(height: 12),
            if (completion != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Entregas: $submitted/$classSize estudantes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text('${(completion * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: completion,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
            ] else
              Text(
                '$submitted entregas registradas · total de estudantes indisponível',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Média',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  average == null ? '—' : '${average.toStringAsFixed(1)}/10',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _editExerciseDialog(context, exercise),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _cloneExerciseDialog(context, exercise),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Clonar'),
                      ),
                      TextButton.icon(
                        onPressed: () => _previewExercise(context, exercise),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Pré-visualizar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editExerciseDialog(
    BuildContext context,
    Map<String, dynamic> exercise,
  ) async {
    final exerciseId = _int(exercise['id']);
    if (exerciseId == null) return;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _EditExerciseDialog(
        exercise: exercise,
        classes: _classes,
        fallbackClassId: _selectedClassId,
      ),
    );

    if (payload == null) return;
    try {
      await _dio.put('/api/exercises/$exerciseId', data: payload);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Atividade atualizada com sucesso!')),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar atividade: $e')),
        );
      }
    }
  }

  Future<void> _cloneExerciseDialog(
    BuildContext context,
    Map<String, dynamic> exercise,
  ) async {
    final availableClasses = _classes;
    if (availableClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma outra turma disponível para clonagem.'),
        ),
      );
      return;
    }

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _CloneExerciseDialog(
        initialTitle: '${exercise['title'] ?? 'Atividade'} (Cópia)',
        classes: availableClasses,
      ),
    );

    if (payload == null) return;
    try {
      final exerciseId = exercise['id'];
      await _dio.post('/api/exercises/$exerciseId/clone', data: payload);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Atividade clonada com sucesso para a turma selecionada!',
            ),
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao clonar atividade: $e')));
      }
    }
  }

  Future<void> _previewExercise(
    BuildContext context,
    Map<String, dynamic> exercise,
  ) {
    final questions = (exercise['questions'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherExercisePreviewScreen(
          title: '${exercise['title'] ?? 'Atividade'}',
          category: '${exercise['category'] ?? 'Geral'}',
          theme: '${exercise['theme'] ?? 'Geral'}',
          level: '${exercise['proficiencyLevel'] ?? 'Intermediário'}',
          questions: questions,
          contentBody: exercise['contentBody']?.toString(),
          mascotHelpMessage: exercise['mascotHelpMessage']?.toString(),
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _categoryChip(BuildContext context, String category) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      label: Text(category),
      visualDensity: VisualDensity.compact,
      backgroundColor: colors.primaryContainer,
      labelStyle: TextStyle(color: colors.onPrimaryContainer, fontSize: 12),
      side: BorderSide.none,
    );
  }

  Widget _statusChip(BuildContext context, bool completed) {
    final colors = Theme.of(context).colorScheme;
    final color = completed ? const Color(0xFF238A5B) : colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        completed ? 'Concluída' : 'Em andamento',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _detailLabel(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _empty(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onRefresh,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const AppEmptyIllustration(
              icon: Icons.assignment_outlined,
              size: 76,
              accentColor: Color(0xFF7651C8),
            ),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataNotice(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onRefresh,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surfaceContainerLow,
      child: ListTile(
        leading: const Icon(
          Icons.info_outline_rounded,
          color: Color(0xFF7651C8),
          size: 30,
        ),
        title: Text(title),
        subtitle: Text(message),
        trailing: IconButton(
          tooltip: 'Atualizar',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
    );
  }

  List<_ExercisePackage> _packages(List<Map<String, dynamic>> exercises) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final categoryByKey = <String, String>{};
    final themeByKey = <String, String>{};
    for (final exercise in exercises) {
      final category = exercise['category']?.toString().trim();
      final theme = exercise['theme']?.toString().trim();
      final categoryName = category == null || category.isEmpty
          ? 'Sem categoria'
          : category;
      final themeName = theme == null || theme.isEmpty ? 'Sem tema' : theme;
      final key = '${categoryName.toLowerCase()}|${themeName.toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add(exercise);
      categoryByKey[key] = categoryName;
      themeByKey[key] = themeName;
    }
    return grouped.entries
        .map(
          (entry) => _ExercisePackage(
            key: entry.key,
            category: categoryByKey[entry.key]!,
            theme: themeByKey[entry.key]!,
            exercises: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) {
        final categoryOrder = a.category.compareTo(b.category);
        return categoryOrder != 0 ? categoryOrder : a.theme.compareTo(b.theme);
      });
  }

  double? _averageScore(List<Map<String, dynamic>> submissions) {
    if (submissions.isEmpty) return null;
    final total = submissions.fold<double>(0, (sum, submission) {
      final correct = _int(submission['correctCount']) ?? 0;
      final questions = _int(submission['questionCount']) ?? 0;
      return sum + (questions == 0 ? 0 : correct / questions * 10);
    });
    return total / submissions.length;
  }

  int? _int(Object? value) => (value as num?)?.toInt();

  String? _dateLabel(Object? value) {
    if (value == null) return null;
    final date = DateTime.tryParse(value.toString());
    if (date == null) return null;
    return 'Criada em ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _parseError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        for (final key in ['message', 'error', 'detail']) {
          final value = data[key];
          if (value is String && value.trim().isNotEmpty) return value;
        }
      }
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        return 'Sua sessão expirou. Entre novamente.';
      }
    }
    return 'Não foi possível carregar as matrículas ativas desta turma.';
  }
}

class _ClassOption {
  const _ClassOption({required this.id, required this.name});
  final int id;
  final String name;
}

class _ExercisePackage {
  const _ExercisePackage({
    required this.key,
    required this.category,
    required this.theme,
    required this.exercises,
  });
  final String key;
  final String category;
  final String theme;
  final List<Map<String, dynamic>> exercises;
}

class _EditExerciseDialog extends StatefulWidget {
  const _EditExerciseDialog({
    required this.exercise,
    required this.classes,
    this.fallbackClassId,
  });

  final Map<String, dynamic> exercise;
  final List<_ClassOption> classes;
  final int? fallbackClassId;

  @override
  State<_EditExerciseDialog> createState() => _EditExerciseDialogState();
}

class _EditExerciseDialogState extends State<_EditExerciseDialog> {
  static const List<String> _defaultCategories = [
    'Gramática',
    'Vocabulário',
    'Conversação',
    'Leitura',
    'Escrita',
    'Pronúncia',
  ];
  static const List<String> _defaultLevels = [
    'Fácil',
    'Médio',
    'Difícil',
    'Básico',
    'Intermediário',
    'Avançado',
  ];

  late final TextEditingController _titleCtrl;
  late final TextEditingController _themeCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _mascotHelpCtrl;
  late String _category;
  late String _level;
  DateTime? _dueDate;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: widget.exercise['title']?.toString() ?? '',
    );
    _themeCtrl = TextEditingController(
      text: widget.exercise['theme']?.toString() ?? '',
    );
    _descriptionCtrl = TextEditingController(
      text: widget.exercise['description']?.toString() ?? '',
    );
    _mascotHelpCtrl = TextEditingController(
      text: widget.exercise['mascotHelpMessage']?.toString() ?? '',
    );

    final rawCat = widget.exercise['category']?.toString().trim() ?? '';
    _category = rawCat.isEmpty ? _defaultCategories.first : rawCat;

    final rawLevel =
        widget.exercise['proficiencyLevel']?.toString().trim() ?? '';
    _level = rawLevel.isEmpty ? 'Intermediário' : rawLevel;

    final rawDue = widget.exercise['dueDate']?.toString().trim();
    if (rawDue != null && rawDue.isNotEmpty) {
      _dueDate = DateTime.tryParse(rawDue);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _themeCtrl.dispose();
    _descriptionCtrl.dispose();
    _mascotHelpCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 3),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _validationError = 'Informe o título da atividade.');
      return;
    }

    final schoolClassId =
        (widget.exercise['schoolClassId'] as num?)?.toInt() ??
        widget.fallbackClassId ??
        widget.classes.firstOrNull?.id;
    if (schoolClassId == null) {
      setState(() => _validationError = 'Turma vinculada não encontrada.');
      return;
    }

    final rawLang = widget.exercise['languageName']?.toString().trim();
    final matchedClassName = widget.classes
        .where((c) => c.id == schoolClassId)
        .map((c) => c.name)
        .firstOrNull;
    final languageName = (rawLang != null && rawLang.isNotEmpty)
        ? SupportedLanguages.normalizeOrDefault(rawLang)
        : SupportedLanguages.inferFromClassName(matchedClassName);

    final dueDateStr = _dueDate == null
        ? null
        : '${_dueDate!.year.toString().padLeft(4, '0')}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}';

    final questions = (widget.exercise['questions'] as List? ?? const [])
        .whereType<Map>()
        .map((q) {
          final rawOpts = q['options'] as List? ?? const [];
          return <String, dynamic>{
            'style': (q['style'] ?? 'Múltipla Escolha').toString(),
            'question': (q['question'] ?? q['prompt'] ?? '').toString(),
            'options': rawOpts.map((e) => e.toString()).toList(),
            if (q['correctAnswer'] != null)
              'correctAnswer': q['correctAnswer'].toString(),
            if (q['expectedAnswer'] != null)
              'expectedAnswer': q['expectedAnswer'].toString(),
          };
        })
        .toList();

    final helpText = _mascotHelpCtrl.text.trim();

    Navigator.of(context).pop(<String, dynamic>{
      'title': title,
      'category': _category,
      'theme': _themeCtrl.text.trim(),
      'languageName': languageName,
      'proficiencyLevel': _level,
      'description': _descriptionCtrl.text.trim(),
      'mascotHelpMessage': helpText.isEmpty ? null : helpText,
      'contentBody': widget.exercise['contentBody'],
      'mediaUrl': widget.exercise['mediaUrl'],
      'dueDate': dueDateStr,
      'schoolClassId': schoolClassId,
      'questions': questions,
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryItems = <String>{
      ..._defaultCategories,
      if (_category.isNotEmpty) _category,
    }.toList();
    final levelItems = <String>{
      ..._defaultLevels,
      if (_level.isNotEmpty) _level,
    }.toList();

    return AlertDialog(
      title: const Row(
        children: [
          MascotPoseEmblem(state: MascotState.clickBleat, size: 32),
          SizedBox(width: 10),
          Expanded(child: Text('Editar Atividade')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título da Atividade',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        isDense: true,
                      ),
                      items: categoryItems
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _level,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Nível',
                        isDense: true,
                      ),
                      items: levelItems
                          .map(
                            (l) => DropdownMenuItem(value: l, child: Text(l)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _level = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _themeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tema',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mascotHelpCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Dica do Bode Branco (opcional)',
                  hintText:
                      'Orientação exibida no balão de ajuda do mascote durante a atividade.',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: Text(
                        _dueDate == null
                            ? 'Prazo (opcional)'
                            : 'Prazo: ${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      tooltip: 'Remover prazo',
                      onPressed: () => setState(() => _dueDate = null),
                      icon: const Icon(Icons.clear_rounded, size: 18),
                    ),
                ],
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _validationError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salvar Alterações'),
        ),
      ],
    );
  }
}
