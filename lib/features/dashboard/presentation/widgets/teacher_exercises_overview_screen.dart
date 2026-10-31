import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/dashboard_data.dart';
import 'responsive_layout.dart';
import 'teacher_exercise_preview_screen.dart';

class TeacherExercisesOverviewScreen extends StatefulWidget {
  const TeacherExercisesOverviewScreen({
    super.key,
    required this.data,
    required this.exercises,
    required this.submissions,
    this.dataLoadError,
    required this.onCreateExercise,
    required this.onRefresh,
  });

  final DashboardData data;
  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> submissions;
  final String? dataLoadError;
  final VoidCallback onCreateExercise;
  final VoidCallback onRefresh;

  @override
  State<TeacherExercisesOverviewScreen> createState() =>
      _TeacherExercisesOverviewScreenState();
}

class _TeacherExercisesOverviewScreenState
    extends State<TeacherExercisesOverviewScreen> {
  final Dio _dio = ApiClient().dio;
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
                    '${_classes.firstWhere((item) => item.id == _selectedClassId).name} · ${classSize == null ? (_loadingStudents ? 'Carregando estudantes…' : 'estudantes não carregados') : '$classSize estudantes'}',
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
                side: BorderSide(color: colors.onPrimary.withValues(alpha: .7)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Criar atividade'),
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
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _previewExercise(context, exercise),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Pré-visualizar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
            Icon(
              Icons.menu_book_outlined,
              size: 40,
              color: colors.onSurfaceVariant,
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
        leading: Icon(Icons.cloud_off_outlined, color: colors.onSurfaceVariant),
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
