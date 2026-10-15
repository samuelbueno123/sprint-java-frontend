import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/student_enrollment.dart';
import 'responsive_layout.dart';
import 'teacher_create_exercise_screen.dart';
import 'teacher_exercises_overview_screen.dart';

String parseLearningError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in ['message', 'error', 'detail']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value;
      }
    }
    return error.response?.statusCode == 401 ||
            error.response?.statusCode == 403
        ? 'Sua sessão expirou. Entre novamente.'
        : 'Não foi possível concluir a operação. Tente novamente.';
  }
  return 'Ocorreu um erro. Tente novamente.';
}

void showLearningError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(parseLearningError(error))));
}

class _ReviewClass {
  const _ReviewClass({required this.id, required this.name});

  final int id;
  final String name;
}

class LearningFeaturePage extends StatefulWidget {
  const LearningFeaturePage({
    super.key,
    required this.section,
    required this.onBackToProfile,
  });

  final String section;
  final VoidCallback onBackToProfile;

  @override
  State<LearningFeaturePage> createState() => _LearningFeaturePageState();
}

class TeacherLearningPage extends StatefulWidget {
  const TeacherLearningPage({
    super.key,
    required this.data,
    required this.section,
    this.onSectionSelected,
  });
  final DashboardData data;
  final String section;
  final ValueChanged<String>? onSectionSelected;

  @override
  State<TeacherLearningPage> createState() => _TeacherLearningPageState();
}

class _TeacherLearningPageState extends State<TeacherLearningPage> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _load;
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _submissions = [];
  List<String> _levels = [];
  String _reviewClassKey = 'all';
  String? _dataLoadError;

  @override
  void initState() {
    super.initState();
    _load = _loadData();
  }

  Future<void> _loadData() async {
    _dataLoadError = null;
    _exercises = [];
    _submissions = [];
    _levels = [];
    final errors = <String>[];
    await Future.wait([
      _dio
          .get('/api/exercises')
          .then((response) {
            _exercises = (response.data as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          })
          .catchError((error) {
            errors.add(_parseError(error));
          }),
      _dio
          .get('/api/exercises/submissions')
          .then((response) {
            _submissions = (response.data as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          })
          .catchError((error) {
            errors.add(_parseError(error));
          }),
      _dio
          .get('/api/catalog/proficiency-levels')
          .then((response) {
            _levels = (response.data as List)
                .map((e) {
                  final item = Map<String, dynamic>.from(e);
                  return (item['name'] ?? item['value'] ?? item['label'])
                      .toString();
                })
                .where((value) => value != 'null')
                .toList();
          })
          .catchError((error) {
            errors.add(_parseError(error));
          }),
    ]);
    if (errors.isNotEmpty) _dataLoadError = errors.toSet().join('\n');
  }

  Future<void> _refresh() async {
    setState(() => _load = _loadData());
    await _load;
  }

  String get _title => widget.section == 'reviewExercises'
      ? 'Analisar respostas'
      : widget.section == 'teacherRanking'
      ? 'Desempenho das atividades'
      : 'Atividades da turma';

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return _ErrorPanel(
          message: _parseError(snapshot.error!),
          onRetry: _refresh,
        );
      if (widget.section == 'reviewExercises') return _reviews();
      if (widget.section == 'teacherRanking') return _performance();
      if (widget.section == 'manageExercises') {
        return TeacherExercisesOverviewScreen(
          data: widget.data,
          exercises: _exercises,
          submissions: _submissions,
          dataLoadError: _dataLoadError,
          onCreateExercise: () =>
              widget.onSectionSelected?.call('createExercise'),
          onRefresh: _refresh,
        );
      }
      return _exerciseList();
    },
  );

  Widget _exerciseList() => TeacherCreateExerciseScreen(
    data: widget.data,
    proficiencyLevels: _levels,
    exercises: _exercises,
    dataLoadError: _dataLoadError,
    onBack: () => widget.onSectionSelected?.call('profile'),
    onSaved: _refresh,
  );

  Widget _reviews() {
    final classes = _reviewClasses;
    final selectedClassId = int.tryParse(_reviewClassKey);
    final submissions = _submissions.where((item) {
      if (selectedClassId == null) return true;
      return _submissionClassId(item) == selectedClassId;
    }).toList();
    final pending = submissions
        .where((item) => item['reviewedAt'] == null)
        .toList();
    final reviewed = submissions
        .where((item) => item['reviewedAt'] != null)
        .toList();
    return ListView(
      padding: responsivePagePadding(context),
      children: [
        Text(
          _title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '${pending.length} respostas aguardando análise · ${reviewed.length} revisadas',
        ),
        const SizedBox(height: 16),
        if (classes.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _reviewClassKey,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Turma',
              prefixIcon: Icon(Icons.groups_outlined),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('Todas as turmas'),
              ),
              ...classes.map(
                (item) => DropdownMenuItem(
                  value: '${item.id}',
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              _reviewClassKey = value ?? 'all';
            }),
          )
        else
          const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Turma',
              prefixIcon: Icon(Icons.groups_outlined),
              border: OutlineInputBorder(),
            ),
            child: Text('Nenhuma turma vinculada ao professor.'),
          ),
        const SizedBox(height: 16),
        if (_dataLoadError != null)
          _DatabaseNotice(
            title: 'Parte dos dados não foi carregada',
            message: _dataLoadError!,
            onRefresh: _refresh,
          )
        else if (submissions.isEmpty)
          _DatabaseNotice(
            title: selectedClassId == null
                ? 'Ainda sem entregas'
                : 'Nenhuma resposta nesta turma',
            message: selectedClassId == null
                ? 'Não há entregas registradas no banco de dados. Atualize para consultar novamente.'
                : 'Não há respostas desta turma registradas no banco de dados. Atualize para consultar novamente.',
            onRefresh: _refresh,
          ),
        for (final item in submissions)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: CircleAvatar(child: Text(_initial(item['studentName']))),
              title: Text(
                '${item['studentName'] ?? 'Estudante'} · ${item['exerciseTitle'] ?? 'Atividade'}',
              ),
              subtitle: Text(
                '${_submissionClassName(item) ?? 'Turma não identificada'} · ${item['correctCount'] ?? 0}/${item['questionCount'] ?? 0} corretas · ${item['xpEarned'] ?? 0} XP · ${item['reviewedAt'] == null ? 'Aguardando análise' : 'Revisada'}',
              ),
              children: [
                for (
                  var i = 0;
                  i < ((item['answers'] as List?) ?? []).length;
                  i++
                )
                  ListTile(
                    dense: true,
                    title: Text('Resposta ${i + 1}'),
                    subtitle: Text('${(item['answers'] as List)[i]}'),
                  ),
                if (item['feedback'] != null)
                  ListTile(
                    title: const Text('Feedback'),
                    subtitle: Text('${item['feedback']}'),
                  ),
                if (item['reviewedAt'] == null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton.icon(
                        onPressed: () => _feedback(item),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Enviar feedback'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<_ReviewClass> get _reviewClasses {
    final names = <int, String>{};
    for (final assignment in widget.data.teacherAssignments) {
      final id = assignment.schoolClassId;
      if (id != null && assignment.schoolClassName.trim().isNotEmpty) {
        names[id] = assignment.schoolClassName;
      }
    }
    for (final exercise in _exercises) {
      final id = (exercise['schoolClassId'] as num?)?.toInt();
      final name = exercise['schoolClassName']?.toString().trim();
      if (id != null && name != null && name.isNotEmpty) {
        names[id] = name;
      }
    }
    final classes =
        names.entries
            .map((entry) => _ReviewClass(id: entry.key, name: entry.value))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    if (_reviewClassKey != 'all' &&
        !classes.any((item) => '${item.id}' == _reviewClassKey)) {
      _reviewClassKey = 'all';
    }
    return classes;
  }

  int? _submissionClassId(Map<String, dynamic> submission) {
    final exerciseId = (submission['exerciseId'] as num?)?.toInt();
    if (exerciseId == null) return null;
    for (final exercise in _exercises) {
      if ((exercise['id'] as num?)?.toInt() == exerciseId) {
        return (exercise['schoolClassId'] as num?)?.toInt();
      }
    }
    return null;
  }

  String? _submissionClassName(Map<String, dynamic> submission) {
    final exerciseId = (submission['exerciseId'] as num?)?.toInt();
    if (exerciseId == null) return null;
    for (final exercise in _exercises) {
      if ((exercise['id'] as num?)?.toInt() == exerciseId) {
        final name = exercise['schoolClassName']?.toString().trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    final classId = _submissionClassId(submission);
    for (final assignment in widget.data.teacherAssignments) {
      if (assignment.schoolClassId == classId)
        return assignment.schoolClassName;
    }
    return null;
  }

  Widget _performance() {
    final totalXp = _submissions.fold<int>(
      0,
      (sum, row) => sum + ((row['xpEarned'] as num?)?.toInt() ?? 0),
    );
    final studentTotals = <String, int>{};
    for (final row in _submissions) {
      final name = '${row['studentName'] ?? 'Estudante'}';
      studentTotals[name] =
          (studentTotals[name] ?? 0) +
          ((row['xpEarned'] as num?)?.toInt() ?? 0);
    }
    final ranking = studentTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: responsivePagePadding(context),
      children: [
        Text(
          _title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _AchievementCard(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Entregas recebidas',
              detail: '${_submissions.length} respostas registradas.',
            ),
            _AchievementCard(
              icon: Icons.bolt_rounded,
              title: 'XP concedido',
              detail: '$totalXp XP somados nas entregas.',
            ),
            _AchievementCard(
              icon: Icons.groups_outlined,
              title: 'Estudantes participantes',
              detail: '${studentTotals.length} estudantes com entrega.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_dataLoadError != null || _submissions.isEmpty)
          _DatabaseNotice(
            title: _dataLoadError == null
                ? 'Sem dados de desempenho'
                : 'Dados de desempenho indisponíveis',
            message:
                _dataLoadError ??
                'Não há respostas registradas no banco de dados. Atualize para consultar novamente.',
            onRefresh: _refresh,
          ),
        for (var i = 0; i < ranking.length; i++)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(ranking[i].key),
              trailing: Text('${ranking[i].value} XP'),
            ),
          ),
      ],
    );
  }

  Future<void> _feedback(Map<String, dynamic> submission) async {
    final controller = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            'Feedback para ${submission['studentName'] ?? 'estudante'}',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Comentário para o estudante',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      );
      if (ok == true && controller.text.trim().isNotEmpty) {
        await _dio.patch(
          '/api/exercises/submissions/${submission['id']}/feedback',
          data: {'feedback': controller.text.trim()},
        );
        await _refresh();
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_parseError(error))));
    } finally {
      controller.dispose();
    }
  }
}

class _LearningFeaturePageState extends State<LearningFeaturePage> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _load;
  List<_Exercise> _exercises = [];
  List<_Submission> _submissions = [];
  List<Map<String, dynamic>> _ranking = [];
  String? _dataLoadError;
  String _period = 'week';
  String _lessonFilter = 'all';
  final Set<String> _collapsedLessonGroups = {};
  _Exercise? _selected;
  _Exercise? _selectedContent;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load = _loadData();
  }

  @override
  void didUpdateWidget(covariant LearningFeaturePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _selected = null;
      _selectedContent = null;
      _lessonFilter = 'all';
      _load = _loadData();
    }
  }

  Future<void> _loadData() async {
    _dataLoadError = null;
    _exercises = [];
    _submissions = [];
    _ranking = [];
    try {
      if (widget.section == 'ranking' || widget.section == 'groupRanking') {
        final type = widget.section == 'groupRanking' ? 'groups' : 'individual';
        final response = await _dio.get(
          '/api/exercises/rankings/$type',
          queryParameters: {'period': _period},
        );
        _ranking = (response.data as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      } else if (widget.section == 'history' ||
          widget.section == 'achievements') {
        final response = await _dio.get('/api/exercises/submissions');
        _submissions = (response.data as List)
            .map(
              (item) => _Submission.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      } else if (widget.section == 'lesson') {
        final responses = await Future.wait([
          _dio.get('/api/exercises'),
          _dio.get('/api/exercises/submissions'),
        ]);
        _exercises = (responses[0].data as List)
            .map((item) => _Exercise.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _submissions = (responses[1].data as List)
            .map(
              (item) => _Submission.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      } else {
        final response = await _dio.get('/api/exercises');
        _exercises = (response.data as List)
            .map((item) => _Exercise.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (error) {
      _dataLoadError = _parseError(error);
    }
  }

  Future<void> _refresh() async {
    setState(() => _load = _loadData());
    await _load;
  }

  String get _title => switch (widget.section) {
    'history' => 'Meu histórico',
    'achievements' => 'Conquistas',
    'ranking' => 'Ranking individual',
    'groupRanking' => 'Ranking de grupos',
    _ => 'Atividades e lições',
  };

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _ErrorPanel(
          message: _parseError(snapshot.error!),
          onRetry: _refresh,
        );
      }
      if (_selected != null)
        return _ExerciseRunPage(
          exercise: _selected!,
          dio: _dio,
          onFinished: () async {
            if (!mounted) return;
            setState(() {
              _selected = null;
              _load = _loadData();
            });
            await _load;
          },
          onBack: () => setState(() => _selected = null),
        );
      if (_selectedContent != null) {
        return _ExerciseContentPage(
          exercise: _selectedContent!,
          onBack: () => setState(() => _selectedContent = null),
        );
      }
      if (widget.section == 'history' ||
          widget.section == 'achievements' ||
          widget.section == 'ranking' ||
          widget.section == 'groupRanking') {
        return _submissionsView();
      }
      if (widget.section == 'lesson') return _lessonsView();
      return ListView(
        padding: responsivePagePadding(context),
        children: [
          Text(
            _title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Atividades enviadas pelos seus professores.'),
          const SizedBox(height: 20),
          if (_dataLoadError != null || _exercises.isEmpty)
            _DatabaseNotice(
              title: _dataLoadError == null
                  ? 'Nenhuma atividade disponível'
                  : 'Atividades indisponíveis',
              message:
                  _dataLoadError ??
                  'Não há atividades registradas no banco de dados para suas turmas. Atualize para consultar novamente.',
              onRefresh: _refresh,
            ),
          for (final exercise in _exercises)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(
                  child: Icon(Icons.menu_book_rounded),
                ),
                title: Text(
                  exercise.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${exercise.language} · ${exercise.className}\n${exercise.description ?? 'Atividade de ${exercise.level}'}',
                ),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _selected = exercise),
                  child: const Text('Começar'),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _submissionsView() {
    if (widget.section == 'ranking' || widget.section == 'groupRanking') {
      return _rankingView(
        grouped: widget.section == 'groupRanking',
        dataLoadError: _dataLoadError,
      );
    }
    if (widget.section == 'achievements') {
      return _achievementsView(dataLoadError: _dataLoadError);
    }
    return ListView(
      padding: responsivePagePadding(context),
      children: [
        Text(
          _title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        if (_dataLoadError != null || _submissions.isEmpty)
          _DatabaseNotice(
            title: _dataLoadError == null
                ? 'Ainda não há resultados'
                : 'Resultados indisponíveis',
            message:
                _dataLoadError ??
                'Não há respostas registradas no banco de dados. Conclua uma atividade e atualize para consultar novamente.',
            onRefresh: _refresh,
          ),
        for (final item in _submissions)
          Card(
            child: ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(item.title),
              subtitle: Text(
                '${item.language} · ${item.correct}/${item.count} corretas${item.feedback == null ? '' : '\nFeedback: ${item.feedback}'}',
              ),
              isThreeLine: item.feedback != null,
              trailing: Text('+${item.xp} XP'),
            ),
          ),
      ],
    );
  }

  Widget _lessonsView() {
    final completedIds = _submissions.map((item) => item.exerciseId).toSet();
    final completed = _exercises
        .where((exercise) => completedIds.contains(exercise.id))
        .toList();
    final pending = _exercises
        .where((exercise) => !completedIds.contains(exercise.id))
        .toList();
    final urgent = pending.where((exercise) {
      final daysLeft = exercise.daysUntilDue;
      return daysLeft != null && daysLeft <= 2;
    }).toList();
    final filtered = switch (_lessonFilter) {
      'pending' => pending,
      'urgent' => urgent,
      'completed' => completed,
      _ => _exercises,
    };
    final grouped = <String, List<_Exercise>>{};
    for (final exercise in filtered) {
      final key = '${exercise.categoryLabel}\u0000${exercise.themeLabel}';
      grouped.putIfAbsent(key, () => []).add(exercise);
    }
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primary, colors.primary.withValues(alpha: .86)],
            ),
          ),
          padding: responsivePagePadding(context).copyWith(top: 20, bottom: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: widget.onBackToProfile,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onPrimary,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Voltar'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_outline_rounded,
                        color: colors.onPrimary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Continuar Aprendendo',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_exercises.length} atividades e conteúdos publicados pelos seus professores',
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: .85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: responsivePagePadding(context).copyWith(top: 20, bottom: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (urgent.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        border: Border.all(
                          color: colors.error.withValues(alpha: .35),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: colors.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${urgent.length} ${urgent.length == 1 ? 'entrega urgente' : 'entregas urgentes'} nos próximos 2 dias ou em atraso.',
                              style: TextStyle(
                                color: colors.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 16) / 3;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _LessonStat(
                            width: width,
                            value: '${pending.length}',
                            label: 'Pendentes',
                            color: colors.secondaryContainer,
                          ),
                          _LessonStat(
                            width: width,
                            value: '${completed.length}',
                            label: 'Concluídas',
                            color: colors.primaryContainer,
                          ),
                          _LessonStat(
                            width: width,
                            value: '${urgent.length}',
                            label: 'Urgentes',
                            color: colors.errorContainer,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _lessonFilterChip('all', 'Todas', _exercises.length),
                      _lessonFilterChip('pending', 'Pendentes', pending.length),
                      _lessonFilterChip('urgent', 'Urgentes', urgent.length),
                      _lessonFilterChip(
                        'completed',
                        'Concluídas',
                        completed.length,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_dataLoadError != null || _exercises.isEmpty)
                    _DatabaseNotice(
                      title: _dataLoadError == null
                          ? 'Nenhuma atividade disponível'
                          : 'Atividades indisponíveis',
                      message:
                          _dataLoadError ??
                          'Não há atividades publicadas no banco de dados para suas turmas. Atualize para consultar novamente.',
                      onRefresh: _refresh,
                    )
                  else if (filtered.isEmpty)
                    _LessonEmptyFilter(filter: _lessonFilter)
                  else
                    for (final entry in grouped.entries) ...[
                      _LessonTopicGroup(
                        category: entry.key.split('\u0000').first,
                        theme: entry.key.split('\u0000').last,
                        count: entry.value.length,
                        expanded: !_collapsedLessonGroups.contains(entry.key),
                        onToggle: () => setState(() {
                          if (!_collapsedLessonGroups.add(entry.key)) {
                            _collapsedLessonGroups.remove(entry.key);
                          }
                        }),
                        children: [
                          for (final exercise in entry.value)
                            _LessonAssignmentCard(
                              exercise: exercise,
                              completed: completedIds.contains(exercise.id),
                              onTap: () {
                                if (completedIds.contains(exercise.id)) return;
                                setState(() {
                                  if (exercise.isContent) {
                                    _selectedContent = exercise;
                                  } else if (exercise.questions.isNotEmpty) {
                                    _selected = exercise;
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lessonFilterChip(String filter, String label, int count) =>
      ChoiceChip(
        label: Text('$label ($count)'),
        selected: _lessonFilter == filter,
        onSelected: (_) => setState(() => _lessonFilter = filter),
      );

  Widget _achievementsView({String? dataLoadError}) {
    final achievements = _buildAchievements(_submissions);

    final earned = achievements.where((item) => item.earned).length;
    final progress = earned / achievements.length;
    final grouped = <String, List<_AchievementMilestone>>{};
    for (final achievement in achievements) {
      grouped.putIfAbsent(achievement.category, () => []).add(achievement);
    }
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primary, colors.primary.withValues(alpha: .86)],
            ),
          ),
          padding: responsivePagePadding(context).copyWith(top: 20, bottom: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: widget.onBackToProfile,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onPrimary,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Voltar'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: colors.onPrimary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Minhas Conquistas',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$earned de ${achievements.length} conquistas desbloqueadas',
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: .85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          color: colors.primaryContainer.withValues(alpha: .35),
          padding: EdgeInsets.symmetric(
            horizontal: responsivePagePadding(context).horizontal / 2,
            vertical: 18,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 11,
                        backgroundColor: colors.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: responsivePagePadding(context).copyWith(top: 24, bottom: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dataLoadError != null || _submissions.isEmpty) ...[
                    _DatabaseNotice(
                      title: dataLoadError == null
                          ? 'Ainda não há progresso registrado'
                          : 'Progresso indisponível',
                      message:
                          dataLoadError ??
                          'Não há respostas registradas no banco de dados. Conclua uma atividade e atualize para consultar novamente.',
                      onRefresh: _refresh,
                    ),
                    const SizedBox(height: 20),
                  ],
                  for (final entry in grouped.entries) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                          ),
                        ),
                        Text(
                          '${entry.value.where((item) => item.earned).length}/${entry.value.length}',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth >= 650
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final achievement in entry.value)
                              SizedBox(
                                width: width,
                                child: _AchievementTile(
                                  achievement: achievement,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rankingView({required bool grouped, String? dataLoadError}) {
    return ListView(
      padding: responsivePagePadding(context),
      children: [
        Text(
          _title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: _period,
          items: const [
            DropdownMenuItem(value: 'week', child: Text('Esta semana')),
            DropdownMenuItem(value: 'month', child: Text('Este mês')),
            DropdownMenuItem(value: 'year', child: Text('Este ano')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _period = value;
              _load = _loadData();
            });
          },
        ),
        const SizedBox(height: 12),
        if (_ranking.isEmpty || dataLoadError != null)
          _DatabaseNotice(
            title: dataLoadError == null
                ? 'Ranking sem resultados neste período'
                : 'Ranking indisponível',
            message:
                dataLoadError ??
                'Não há resultados registrados no banco de dados para este período. Atualize para consultar novamente.',
            onRefresh: _refresh,
          ),
        for (final row in _ranking)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${row['rank'] ?? ''}')),
              title: Text(
                '${grouped ? row['className'] ?? 'Turma' : row['studentName'] ?? 'Estudante'}',
              ),
              subtitle: Text(
                '${row['activitiesCompleted'] ?? 0} atividades · ${row['correctAnswers'] ?? 0}/${row['questionCount'] ?? 0} corretas',
              ),
              trailing: Text('${row['xpEarned'] ?? 0} XP'),
            ),
          ),
      ],
    );
  }
}

class _ExerciseRunPage extends StatefulWidget {
  const _ExerciseRunPage({
    required this.exercise,
    required this.dio,
    required this.onFinished,
    required this.onBack,
  });
  final _Exercise exercise;
  final Dio dio;
  final VoidCallback onBack;
  final VoidCallback onFinished;

  @override
  State<_ExerciseRunPage> createState() => _ExerciseRunPageState();
}

class _ExerciseRunPageState extends State<_ExerciseRunPage> {
  final _text = TextEditingController();
  final List<String> _answers = [];
  final List<String?> _selected = [];
  bool _saving = false;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _answers.addAll(List<String>.filled(widget.exercise.questions.length, ''));
    _selected.addAll(
      List<String?>.filled(widget.exercise.questions.length, null),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _next() {
    final q = widget.exercise.questions[_index];
    final answer = q.options.isEmpty
        ? _text.text.trim()
        : (_selected[_index] ?? '');
    if (answer.isEmpty) return;
    _answers[_index] = answer;
    if (_index < widget.exercise.questions.length - 1) {
      setState(() {
        _index++;
        _text.clear();
      });
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final response = await widget.dio.post(
        '/api/exercises/${widget.exercise.id}/submissions',
        data: {'answers': _answers},
      );
      if (!mounted) return;
      final result = Map<String, dynamic>.from(response.data as Map);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFC400),
            size: 48,
          ),
          title: const Text('Atividade concluída!'),
          content: Text(
            '${result['correctCount']}/${result['questionCount']} respostas corretas · ${result['xpEarned']} XP ganhos',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      widget.onFinished();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_parseError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exercise.questions.isEmpty)
      return _EmptyPanel(
        title: 'Atividade sem questões',
        message: 'Peça ao professor para atualizar esta atividade.',
        onRefresh: widget.onBack,
      );
    final q = widget.exercise.questions[_index];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: responsivePagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      widget.exercise.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text('${_index + 1}/${widget.exercise.questions.length}'),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (_index + 1) / widget.exercise.questions.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 32),
              Text(
                q.prompt,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (q.options.isEmpty)
                TextField(
                  controller: _text,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Sua resposta',
                    border: OutlineInputBorder(),
                  ),
                ),
              for (final option in q.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    onPressed: () => setState(() => _selected[_index] = option),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selected[_index] == option
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(option),
                    ),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _next,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _index == widget.exercise.questions.length - 1
                            ? 'Enviar atividade'
                            : 'Continuar',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonStat extends StatelessWidget {
  const _LessonStat({
    required this.width,
    required this.value,
    required this.label,
    required this.color,
  });
  final double width;
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonTopicGroup extends StatelessWidget {
  const _LessonTopicGroup({
    required this.category,
    required this.theme,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });
  final String category, theme;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: expanded ? .25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 130),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      category,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSecondaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      theme,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count ${count == 1 ? 'item' : 'itens'}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: children),
            ),
          ],
        ],
      ),
    );
  }
}

class _LessonAssignmentCard extends StatelessWidget {
  const _LessonAssignmentCard({
    required this.exercise,
    required this.completed,
    required this.onTap,
  });
  final _Exercise exercise;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final daysLeft = exercise.daysUntilDue;
    final urgent = !completed && daysLeft != null && daysLeft <= 2;
    final openable = exercise.isContent || exercise.questions.isNotEmpty;
    final metadata = [
      if (exercise.teacher.trim().isNotEmpty) exercise.teacher,
      if (exercise.className.trim().isNotEmpty) exercise.className,
      if (exercise.language.trim().isNotEmpty) exercise.language,
      if (exercise.level.trim().isNotEmpty) exercise.level,
    ].join(' · ');
    final remainingLabel = daysLeft == null
        ? null
        : daysLeft < 0
        ? 'Atrasada ${daysLeft.abs()} d'
        : daysLeft == 0
        ? 'Hoje'
        : daysLeft == 1
        ? '1 dia'
        : '$daysLeft dias';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: urgent
              ? colors.error.withValues(alpha: .5)
              : colors.outlineVariant,
          width: urgent ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: !completed && openable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: exercise.isContent
                      ? colors.tertiaryContainer
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  exercise.isContent
                      ? Icons.description_outlined
                      : Icons.menu_book_rounded,
                  color: exercise.isContent
                      ? colors.onTertiaryContainer
                      : colors.onPrimaryContainer,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          exercise.title,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _LessonBadge(
                          label: exercise.isContent ? 'Conteúdo' : 'Atividade',
                          color: exercise.isContent
                              ? colors.tertiaryContainer
                              : colors.primaryContainer,
                          textColor: exercise.isContent
                              ? colors.onTertiaryContainer
                              : colors.onPrimaryContainer,
                        ),
                        if (completed)
                          _LessonBadge(
                            label: 'Concluída',
                            color: colors.primaryContainer,
                            textColor: colors.onPrimaryContainer,
                          ),
                      ],
                    ),
                    if (exercise.description?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 5),
                      Text(
                        exercise.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (metadata.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        metadata,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          exercise.dueDateLabel,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        if (remainingLabel != null && !completed)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (urgent) ...[
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: colors.error,
                                ),
                                const SizedBox(width: 3),
                              ] else ...[
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                remainingLabel,
                                style: TextStyle(
                                  color: urgent
                                      ? colors.error
                                      : colors.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        if (!openable && !completed)
                          Text(
                            'Conteúdo indisponível',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!completed && openable) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonBadge extends StatelessWidget {
  const _LessonBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });
  final String label;
  final Color color, textColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _LessonEmptyFilter extends StatelessWidget {
  const _LessonEmptyFilter({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final message = switch (filter) {
      'pending' => 'Você não tem atividades pendentes.',
      'urgent' => 'Nenhuma entrega urgente. Continue assim!',
      'completed' => 'Você ainda não concluiu atividades.',
      _ => 'Nenhuma atividade encontrada.',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 42,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ExerciseContentPage extends StatelessWidget {
  const _ExerciseContentPage({required this.exercise, required this.onBack});
  final _Exercise exercise;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mediaUrl = exercise.mediaUrl?.trim() ?? '';
    final isImage =
        mediaUrl.isNotEmpty &&
        RegExp(
          r'\.(png|jpe?g|gif|webp)(\?.*)?$',
          caseSensitive: false,
        ).hasMatch(mediaUrl);
    return ListView(
      padding: responsivePagePadding(context),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar às lições'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          exercise.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          [
            exercise.teacher,
            exercise.className,
            exercise.language,
          ].where((value) => value.trim().isNotEmpty).join(' · '),
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Card(
          color: colors.surface,
          child: Padding(
            padding: responsiveCardPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (exercise.description?.trim().isNotEmpty ?? false) ...[
                  Text(
                    exercise.description!,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                ],
                if (exercise.contentBody?.trim().isNotEmpty ?? false)
                  SelectableText(
                    exercise.contentBody!,
                    style: TextStyle(
                      color: colors.onSurface,
                      height: 1.6,
                      fontSize: 15,
                    ),
                  ),
                if (mediaUrl.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  if (isImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        mediaUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Text(
                          'Não foi possível carregar a mídia.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    SelectableText(
                      'Link do material: $mediaUrl',
                      style: TextStyle(color: colors.primary),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Exercise {
  const _Exercise({
    required this.id,
    required this.title,
    required this.language,
    required this.level,
    required this.className,
    required this.category,
    required this.theme,
    required this.teacher,
    required this.questions,
    this.description,
    this.contentBody,
    this.mediaUrl,
    this.dueDate,
  });
  final int id;
  final String title, language, level, className, category, theme, teacher;
  final String? description, contentBody, mediaUrl;
  final DateTime? dueDate;
  final List<_ExerciseQuestion> questions;
  bool get isContent =>
      questions.isEmpty &&
      ((contentBody?.trim().isNotEmpty ?? false) ||
          (mediaUrl?.trim().isNotEmpty ?? false));
  String get categoryLabel =>
      category.trim().isEmpty ? 'Sem categoria' : category;
  String get themeLabel => theme.trim().isEmpty ? 'Sem tema' : theme;
  int? get daysUntilDue {
    if (dueDate == null) return null;
    final today = DateTime.now();
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    return due.difference(todayDate).inDays;
  }

  String get dueDateLabel => dueDate == null
      ? 'Sem prazo de entrega'
      : 'Entrega: ${dueDate!.day.toString().padLeft(2, '0')}/${dueDate!.month.toString().padLeft(2, '0')}/${dueDate!.year}';

  factory _Exercise.fromJson(Map<String, dynamic> json) => _Exercise(
    id: json['id'] as int,
    title: json['title'] as String? ?? 'Atividade',
    language: json['languageName'] as String? ?? '',
    level: json['proficiencyLevel'] as String? ?? '',
    className: json['schoolClassName'] as String? ?? '',
    category: json['category'] as String? ?? '',
    theme: json['theme'] as String? ?? '',
    teacher: json['teacherName'] as String? ?? '',
    description: json['description'] as String?,
    contentBody: json['contentBody'] as String?,
    mediaUrl: json['mediaUrl'] as String?,
    dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? ''),
    questions: (json['questions'] as List? ?? [])
        .map(
          (item) => _ExerciseQuestion.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
  );
}

class _ExerciseQuestion {
  const _ExerciseQuestion(this.prompt, this.options);
  final String prompt;
  final List<String> options;
  factory _ExerciseQuestion.fromJson(Map<String, dynamic> json) =>
      _ExerciseQuestion(
        json['question'] as String? ?? '',
        (json['options'] as List? ?? [])
            .map((item) => item.toString())
            .toList(),
      );
}

class _Submission {
  const _Submission({
    required this.exerciseId,
    required this.title,
    required this.language,
    required this.correct,
    required this.count,
    required this.xp,
    this.feedback,
    this.submittedAt,
  });
  final int exerciseId;
  final String title, language;
  final int correct, count, xp;
  final String? feedback;
  final DateTime? submittedAt;
  factory _Submission.fromJson(Map<String, dynamic> json) => _Submission(
    exerciseId: json['exerciseId'] as int,
    title: json['exerciseTitle'] as String? ?? 'Atividade',
    language: json['languageName'] as String? ?? '',
    correct: json['correctCount'] as int? ?? 0,
    count: json['questionCount'] as int? ?? 0,
    xp: json['xpEarned'] as int? ?? 0,
    feedback: json['feedback'] as String?,
    submittedAt: DateTime.tryParse(
      json['submittedAt']?.toString() ?? '',
    )?.toLocal(),
  );
}

List<_AchievementMilestone> _buildAchievements(List<_Submission> submissions) {
  final dated = submissions.where((item) => item.submittedAt != null).toList()
    ..sort((a, b) => a.submittedAt!.compareTo(b.submittedAt!));
  final totalXp = submissions.fold<int>(0, (sum, item) => sum + item.xp);
  final milestones = <_AchievementMilestone>[];

  DateTime? dateAtXp(int target) {
    var accumulated = 0;
    for (final submission in dated) {
      accumulated += submission.xp;
      if (accumulated >= target) return submission.submittedAt;
    }
    return null;
  }

  DateTime? dateAtSubmissionCount(int target) =>
      dated.length >= target ? dated[target - 1].submittedAt : null;

  final days =
      dated
          .map(
            (item) => DateTime(
              item.submittedAt!.year,
              item.submittedAt!.month,
              item.submittedAt!.day,
            ),
          )
          .toSet()
          .toList()
        ..sort();
  DateTime? dateAtStreak(int target) {
    var run = 1;
    for (var index = 1; index < days.length; index++) {
      run = days[index].difference(days[index - 1]).inDays == 1 ? run + 1 : 1;
      if (run >= target) return days[index];
    }
    return null;
  }

  void add({
    required String category,
    required String title,
    required String description,
    required IconData icon,
    required DateTime? earnedAt,
  }) {
    milestones.add(
      _AchievementMilestone(
        category: category,
        title: title,
        description: description,
        icon: icon,
        earnedAt: earnedAt,
      ),
    );
  }

  for (final target in [7, 30, 100]) {
    add(
      category: 'Sequência',
      title: target == 100 ? 'Maratonista' : 'Sequência de $target dias',
      description: 'Conclua atividades por $target dias seguidos',
      icon: Icons.local_fire_department_rounded,
      earnedAt: dateAtStreak(target),
    );
  }
  for (final target in [100, 500, 1000]) {
    add(
      category: 'XP',
      title: target == 100 ? 'Primeiros 100 XP' : '$target XP',
      description: 'Acumule $target pontos de experiência',
      icon: target == 1000 ? Icons.star_rounded : Icons.bolt_rounded,
      earnedAt: totalXp >= target ? dateAtXp(target) : null,
    );
  }
  add(
    category: 'Exercícios',
    title: 'Primeira Lição',
    description: 'Conclua sua primeira atividade',
    icon: Icons.menu_book_rounded,
    earnedAt: dateAtSubmissionCount(1),
  );
  add(
    category: 'Exercícios',
    title: '10 Lições Completas',
    description: 'Conclua 10 atividades no total',
    icon: Icons.menu_book_rounded,
    earnedAt: dateAtSubmissionCount(10),
  );
  DateTime? firstPerfectDate;
  for (final submission in dated) {
    if (submission.count > 0 && submission.correct == submission.count) {
      firstPerfectDate = submission.submittedAt;
      break;
    }
  }
  add(
    category: 'Exercícios',
    title: 'Nota Perfeita',
    description: 'Acerte todas as questões de uma atividade',
    icon: Icons.emoji_events_rounded,
    earnedAt: firstPerfectDate,
  );
  DateTime? precisionDate;
  var accurateRun = 0;
  for (final submission in dated) {
    final isAccurate =
        submission.count > 0 && submission.correct / submission.count >= .95;
    accurateRun = isAccurate ? accurateRun + 1 : 0;
    if (accurateRun >= 5) {
      precisionDate = submission.submittedAt;
      break;
    }
  }
  add(
    category: 'Exercícios',
    title: 'Precisão Cirúrgica',
    description: 'Acerte pelo menos 95% em 5 atividades seguidas',
    icon: Icons.gps_fixed_rounded,
    earnedAt: precisionDate,
  );
  return milestones;
}

class _AchievementMilestone {
  const _AchievementMilestone({
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.earnedAt,
  });
  final String category, title, description;
  final IconData icon;
  final DateTime? earnedAt;
  bool get earned => earnedAt != null;
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});
  final _AchievementMilestone achievement;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconColor = achievement.earned
        ? colors.primary
        : colors.onSurfaceVariant;
    final date = achievement.earnedAt;
    final dateLabel = date == null
        ? null
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Card(
      margin: EdgeInsets.zero,
      elevation: achievement.earned ? 1 : 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: achievement.earned
              ? colors.primaryContainer
              : colors.outlineVariant,
          width: achievement.earned ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: achievement.earned
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(achievement.icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        achievement.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      if (achievement.earned)
                        Icon(
                          Icons.check_circle_rounded,
                          color: colors.primary,
                          size: 17,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (dateLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Conquistado em $dateLabel',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(detail),
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.title,
    required this.message,
    required this.onRefresh,
  });
  final String title, message;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 54, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar'),
          ),
        ],
      ),
    ),
  );
}

class _DatabaseNotice extends StatelessWidget {
  const _DatabaseNotice({
    required this.title,
    required this.message,
    required this.onRefresh,
  });

  final String title;
  final String message;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_outlined, color: colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Atualizar'),
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
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: responsivePagePadding(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
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
    return 'Não foi possível carregar os dados. Confira sua conexão e tente novamente.';
  }
  return 'Ocorreu um erro ao carregar os dados.';
}

String _initial(Object? name) {
  final value = name?.toString().trim() ?? '';
  return value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();
}

class StudentLanguageManager extends StatefulWidget {
  const StudentLanguageManager({super.key, required this.data});
  final DashboardData data;
  @override
  State<StudentLanguageManager> createState() => _StudentLanguageManagerState();
}

class _StudentLanguageManagerState extends State<StudentLanguageManager> {
  final _name = TextEditingController();
  String _level = 'Iniciante';
  bool _busy = false;
  final _levels = const [
    'Iniciante',
    'Básico',
    'Intermediário',
    'Avançado',
    'Fluente',
  ];
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = widget.data.studentProfile;
    if (profile?.id == null || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final languages = [
        ...profile!.languages.map((v) {
          final parts = v.split(':');
          return {
            'languageName': parts.first.trim(),
            'level': parts.length > 1 ? parts.last.trim() : 'Iniciante',
            'score': 0,
          };
        }),
      ];
      final existing = languages.indexWhere(
        (v) =>
            (v['languageName'] as String).toLowerCase() ==
            _name.text.trim().toLowerCase(),
      );
      final item = {
        'languageName': _name.text.trim(),
        'level': _level,
        'score': 0,
      };
      if (existing >= 0) {
        languages[existing] = item;
      } else {
        languages.add(item);
      }
      await ApiClient().dio.put(
        '${AppConfig.studentsEndpoint}/${profile.id}',
        data: {
          'name': profile.name,
          'email': profile.email,
          'googleId': profile.googleId,
          'languages': languages,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showLearningError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    title: const Text('Adicionar ou editar idioma'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Idioma'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _level,
          decoration: const InputDecoration(labelText: 'Proficiência'),
          items: _levels
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => _level = v ?? _level),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Salvando...' : 'Salvar'),
      ),
    ],
  );
}

class StudentClassesView extends StatelessWidget {
  const StudentClassesView({
    super.key,
    required this.data,
    required this.onRefresh,
  });
  final DashboardData data;
  final VoidCallback onRefresh;

  Future<void> _requestEnrollment(BuildContext context) async {
    final studentId = data.studentProfile?.id;
    if (studentId == null) return;
    final search = TextEditingController();
    try {
      final results = await Future.wait([
        ApiClient().dio.get<List<dynamic>>(
          '${AppConfig.apiBaseUrl}/api/classes',
        ),
        ApiClient().dio.get<List<dynamic>>(
          '${AppConfig.apiBaseUrl}/api/schools',
        ),
      ]);
      final classes = results[0];
      final schools = (results[1].data ?? [])
          .whereType<Map>()
          .fold<Map<int, String>>({}, (map, school) {
            final id = (school['id'] as num?)?.toInt();
            if (id != null) map[id] = '${school['name'] ?? 'Escola'}';
            return map;
          });
      if (!context.mounted) return;
      final rows = (classes.data ?? [])
          .whereType<Map>()
          .where((c) => c['active'] != false)
          .toList();
      final selected = await showDialog<Map?>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text('Solicitar matrícula'),
            content: SizedBox(
              width: responsiveDialogWidth(ctx, maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por escola, turma ou ano',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: ListView(
                      children: rows
                          .where(
                            (c) =>
                                '${c['name']} ${schools[(c['schoolId'] as num?)?.toInt()] ?? ''} ${c['schoolYear']}'
                                    .toLowerCase()
                                    .contains(search.text.toLowerCase()),
                          )
                          .map(
                            (c) => ListTile(
                              title: Text('${c['name'] ?? 'Turma'}'),
                              subtitle: Text(
                                '${schools[(c['schoolId'] as num?)?.toInt()] ?? 'Escola'} • ${c['schoolYear'] ?? ''} • ${c['shift'] ?? ''} • ${c['gradeLevel'] ?? ''}',
                              ),
                              onTap: () => Navigator.pop(ctx, c),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      );
      if (selected == null || !context.mounted) return;
      await ApiClient().dio.post(
        '${AppConfig.apiBaseUrl}/api/enrollments',
        data: {
          'studentId': studentId,
          'schoolClassId': selected['id'],
          'enrollmentDate': DateTime.now().toIso8601String().substring(0, 10),
        },
      );
      onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação de matrícula enviada.')),
      );
    } catch (e) {
      if (context.mounted) showLearningError(context, e);
    } finally {
      search.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: responsivePagePadding(context),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Minhas turmas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _requestEnrollment(context),
            icon: const Icon(Icons.add),
            label: const Text('Solicitar matrícula'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (data.studentEnrollments.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Você ainda não possui turmas ativas.'),
          ),
        ),
      ...data.studentEnrollments.map(
        (e) => _EnrollmentCard(enrollment: e, onRefresh: onRefresh),
      ),
    ],
  );
}

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({required this.enrollment, required this.onRefresh});
  final StudentEnrollment enrollment;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.groups)),
      title: Text(enrollment.schoolClassName),
      subtitle: Text('${enrollment.status} • ${enrollment.enrollmentDate}'),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          try {
            if (v == 'cancel')
              await ApiClient().dio.post(
                '${AppConfig.apiBaseUrl}/api/enrollments/${enrollment.id}/cancel',
              );
            if (v == 'transfer') {
              final idController = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  title: const Text('Solicitar transferência'),
                  content: TextField(
                    controller: idController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ID da nova turma',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Solicitar'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ApiClient().dio.post(
                  '${AppConfig.apiBaseUrl}/api/enrollments/student/${enrollment.studentId}/transfer',
                  data: {
                    'newSchoolClassId': int.tryParse(idController.text),
                    'transferDate': DateTime.now().toIso8601String().substring(
                      0,
                      10,
                    ),
                    'notes': 'Transferência solicitada pelo estudante',
                  },
                );
              }
              idController.dispose();
            }
            onRefresh();
          } catch (e) {
            if (context.mounted) showLearningError(context, e);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'transfer',
            child: Text('Solicitar transferência'),
          ),
          PopupMenuItem(value: 'cancel', child: Text('Cancelar matrícula')),
        ],
      ),
    ),
  );
}

class TeacherClassManagementView extends StatelessWidget {
  const TeacherClassManagementView({
    super.key,
    required this.data,
    required this.onRefresh,
  });
  final DashboardData data;
  final VoidCallback onRefresh;
  Future<void> _create(BuildContext context) async {
    final school = TextEditingController();
    final name = TextEditingController();
    final year = TextEditingController(text: DateTime.now().year.toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Criar turma'),
        content: SizedBox(
          width: responsiveDialogWidth(ctx, maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: school,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ID da escola'),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome da turma'),
              ),
              TextField(
                controller: year,
                decoration: const InputDecoration(labelText: 'Ano letivo'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (result != true) return;
    try {
      final response = await ApiClient().dio.post<Map<String, dynamic>>(
        '${AppConfig.apiBaseUrl}/api/classes/school/${school.text}',
        data: {
          'name': name.text,
          'schoolYear': year.text,
          'shift': 'MANHÃ',
          'gradeLevel': 'Geral',
          'active': true,
        },
      );
      final classId = response.data?['id'];
      final teacherId = data.teacherProfile?.id;
      if (classId != null && teacherId != null) {
        await ApiClient().dio.post(
          '${AppConfig.apiBaseUrl}/api/class-teacher-assignments',
          data: {
            'schoolClassId': classId,
            'teacherId': teacherId,
            'startDate': DateTime.now().toIso8601String().substring(0, 10),
            'reason': 'Turma criada pelo professor',
          },
        );
      }
      onRefresh();
    } catch (e) {
      if (context.mounted) showLearningError(context, e);
    }
    school.dispose();
    name.dispose();
    year.dispose();
  }

  Future<void> _showStudents(BuildContext context, int? classId) async {
    if (classId == null) return;
    try {
      final responses = await Future.wait([
        ApiClient().dio.get<List<dynamic>>(
          '${AppConfig.apiBaseUrl}/api/students/class/$classId/active',
        ),
        ApiClient().dio.get<List<dynamic>>(
          '${AppConfig.apiBaseUrl}/api/enrollments/class/$classId',
        ),
      ]);
      final students = (responses[0].data ?? []).whereType<Map>().toList();
      final enrollments = (responses[1].data ?? []).whereType<Map>().toList();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Estudantes ativos'),
          content: SizedBox(
            width: responsiveDialogWidth(ctx, maxWidth: 500),
            height: 360,
            child: students.isEmpty
                ? const Center(
                    child: Text('Esta turma ainda não tem estudantes.'),
                  )
                : ListView(
                    children: students.map((s) {
                      final matching = enrollments.where(
                        (e) => e['studentId'] == s['id'],
                      );
                      final enrollment = matching.isEmpty
                          ? null
                          : matching.first;
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text('${s['name'] ?? 'Estudante'}'),
                        subtitle: Text(
                          '${s['email'] ?? ''} • ${enrollment?['status'] ?? 'Ativo'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (enrollment?['id'] == null) return;
                            final newStatus = switch (action) {
                              'approve' || 'resume' => 'ACTIVE',
                              'suspend' => 'SUSPENDED',
                              _ => 'CANCELLED',
                            };
                            try {
                              await ApiClient().dio.put(
                                '${AppConfig.apiBaseUrl}/api/enrollments/${enrollment!['id']}/status',
                                data: {
                                  'status': newStatus,
                                  'notes': 'Atualizado pelo professor',
                                },
                              );
                              Navigator.pop(ctx);
                              onRefresh();
                            } catch (e) {
                              if (context.mounted)
                                showLearningError(context, e);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'approve',
                              child: Text('Aprovar / ativar'),
                            ),
                            PopupMenuItem(
                              value: 'suspend',
                              child: Text('Trancar matrícula'),
                            ),
                            PopupMenuItem(
                              value: 'resume',
                              child: Text('Reativar matrícula'),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Remover da turma'),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) showLearningError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: responsivePagePadding(context),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Gestão de turmas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add),
            label: const Text('Criar turma'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (data.teacherAssignments.isEmpty)
        Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Não há turmas atribuídas registradas no banco de dados. Atualize ou crie uma turma para começar.',
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Atualizar'),
                ),
              ],
            ),
          ),
        ),
      ...data.teacherAssignments.map(
        (a) => Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.class_)),
            title: Text(a.schoolClassName),
            subtitle: Text('Desde ${a.startDate}'),
            trailing: IconButton(
              tooltip: 'Ver estudantes',
              icon: const Icon(Icons.people),
              onPressed: () => _showStudents(context, a.schoolClassId),
            ),
          ),
        ),
      ),
    ],
  );
}
