import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/student_enrollment.dart';
import '../../domain/entities/student_profile.dart';
import 'audio_speech_helper.dart';
import 'info_stat_card.dart';
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
  int? _selectedSubmissionId;
  final TextEditingController _packageFeedbackCtrl = TextEditingController();
  bool _sendingFeedback = false;

  @override
  void dispose() {
    _packageFeedbackCtrl.dispose();
    super.dispose();
  }

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
            final fetched = (response.data as List)
                .map((e) {
                  if (e is String) return e;
                  final item = Map<String, dynamic>.from(e);
                  return (item['name'] ?? item['value'] ?? item['label'])
                      .toString();
                })
                .where((value) => value != 'null' && value.trim().isNotEmpty)
                .toList();
            _levels = fetched.isNotEmpty
                ? fetched
                : const ['Fácil', 'Médio', 'Difícil'];
          })
          .catchError((error) {
            _levels = const ['Fácil', 'Médio', 'Difícil'];
          }),
    ]);
    if (_levels.isEmpty) {
      _levels = const ['Fácil', 'Médio', 'Difícil'];
    }
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
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    if (submissions.isNotEmpty) {
      if (_selectedSubmissionId == null ||
          !submissions.any((s) => s['id'] == _selectedSubmissionId)) {
        final initial = pending.isNotEmpty ? pending.first : submissions.first;
        _selectedSubmissionId = initial['id'] as int?;
        _packageFeedbackCtrl.text = initial['feedback']?.toString() ?? '';
      }
    }

    final selectedItem = submissions.firstWhere(
      (s) => s['id'] == _selectedSubmissionId,
      orElse: () =>
          submissions.isNotEmpty ? submissions.first : <String, dynamic>{},
    );

    return ListView(
      padding: responsivePagePadding(context),
      children: [
        // Top Violet Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => widget.onSectionSelected?.call('profile'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Voltar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Analisar Respostas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Revise os pacotes de exercícios e envie feedback aos alunos',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (classes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DropdownButtonFormField<String>(
              initialValue: _reviewClassKey,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filtrar por Turma',
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
                _selectedSubmissionId = null;
              }),
            ),
          ),

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
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final leftPane = _buildReviewsLeftPane(
                pending: pending,
                reviewed: reviewed,
                selectedId: _selectedSubmissionId,
                isDark: isDark,
                colors: colors,
              );
              final rightPane = _buildReviewsRightPane(
                item: selectedItem,
                isDark: isDark,
                colors: colors,
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 320, child: leftPane),
                    const SizedBox(width: 16),
                    Expanded(child: rightPane),
                  ],
                );
              }
              return Column(
                children: [
                  leftPane,
                  const SizedBox(height: 16),
                  rightPane,
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildReviewsLeftPane({
    required List<Map<String, dynamic>> pending,
    required List<Map<String, dynamic>> reviewed,
    required int? selectedId,
    required bool isDark,
    required ColorScheme colors,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? colors.outlineVariant : const Color(0xFFE2E8F0),
        ),
      ),
      color: isDark ? colors.surfaceContainer : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.forum_outlined,
                  color: Color(0xFF8B5CF6),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pacotes Pendentes (${pending.length})',
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // PENDENTES section
            Text(
              '⏳ PENDENTES (${pending.length})',
              style: const TextStyle(
                color: Color(0xFFD97706),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhum pacote pendente.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final item in pending) ...[
                _buildSubmissionCardTile(
                  item: item,
                  isSelected: item['id'] == selectedId,
                  isDark: isDark,
                  colors: colors,
                ),
                const SizedBox(height: 8),
              ],

            const SizedBox(height: 14),
            // REVISADOS section
            Text(
              '✓ REVISADOS (${reviewed.length})',
              style: const TextStyle(
                color: Color(0xFF059669),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            if (reviewed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhum pacote revisado ainda.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final item in reviewed) ...[
                _buildSubmissionCardTile(
                  item: item,
                  isSelected: item['id'] == selectedId,
                  isDark: isDark,
                  colors: colors,
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionCardTile({
    required Map<String, dynamic> item,
    required bool isSelected,
    required bool isDark,
    required ColorScheme colors,
  }) {
    final int correct = (item['correctCount'] as num?)?.toInt() ?? 0;
    final int total = (item['questionCount'] as num?)?.toInt() ?? 0;
    final int safeTotal = total <= 0 ? 1 : total;
    final int percent = ((correct / safeTotal) * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSubmissionId = item['id'] as int?;
            _packageFeedbackCtrl.text = item['feedback']?.toString() ?? '';
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.18)
                    : const Color(0xFFF5F3FF))
                : (isDark ? colors.surfaceContainerLow : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF8B5CF6)
                  : (isDark
                      ? colors.outlineVariant
                      : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isSelected
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFFEDE9FE),
                child: Text(
                  _initial(item['studentName']),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSelected ? Colors.white : const Color(0xFF6D28D9),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['studentName'] ?? 'Estudante',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['exerciseTitle'] ?? 'Módulo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item['questionCount'] ?? 0} ativ. · $percent%',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsRightPane({
    required Map<String, dynamic> item,
    required bool isDark,
    required ColorScheme colors,
  }) {
    if (item.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? colors.outlineVariant : const Color(0xFFE2E8F0),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Selecione uma entrega à esquerda para revisar os exercícios e enviar feedback.',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
    }

    final int correct = (item['correctCount'] as num?)?.toInt() ?? 0;
    final int total = (item['questionCount'] as num?)?.toInt() ?? 0;
    final int safeTotal = total <= 0 ? 1 : total;
    final int percent = ((correct / safeTotal) * 100).round();
    final questionFeedback = ((item['questionFeedback'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: Student Header Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? colors.outlineVariant : const Color(0xFFE2E8F0),
            ),
          ),
          color: isDark ? colors.surfaceContainer : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFEDE9FE),
                  child: Text(
                    _initial(item['studentName']),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['studentName'] ?? 'Estudante',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['exerciseTitle'] ?? 'Módulo / Pacote',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enviado em: ${_formatSubmissionDate(item['submittedAt'])} · ${_submissionClassName(item) ?? ''} · ${_reviewStatusLabel(item)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.trending_up_rounded,
                                color: Color(0xFF7C3AED),
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$percent%',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$correct/$total pontos',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7C3AED),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => _feedback(item),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: const Text(
                        'Ajustar nota',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Card 2: Exercícios do Pacote
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? colors.outlineVariant : const Color(0xFFE2E8F0),
            ),
          ),
          color: isDark ? colors.surfaceContainer : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exercícios do Pacote (${questionFeedback.isNotEmpty ? questionFeedback.length : 1})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(height: 14),
                if (questionFeedback.isNotEmpty)
                  for (var i = 0; i < questionFeedback.length; i++) ...[
                    _buildExercisePackageRow(
                      index: i,
                      qf: questionFeedback[i],
                      defaultTitle: item['exerciseTitle'] ?? 'Exercício',
                      colors: colors,
                    ),
                    if (i < questionFeedback.length - 1)
                      const SizedBox(height: 12),
                  ]
                else
                  _buildExercisePackageRow(
                    index: 0,
                    qf: {
                      'question': item['exerciseTitle'] ?? 'Exercício Geral',
                      'correct': correct > 0,
                      'correctCount': correct,
                      'questionCount': total,
                    },
                    defaultTitle: item['exerciseTitle'] ?? 'Exercício',
                    colors: colors,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Card 3: Feedback do Pacote
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? colors.outlineVariant : const Color(0xFFE2E8F0),
            ),
          ),
          color: isDark ? colors.surfaceContainer : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF7C3AED),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Feedback do Pacote',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Escreva um feedback geral para todo o pacote de exercícios do aluno.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _packageFeedbackCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        "Ex: Ótimo trabalho no módulo! Você mostrou bom domínio dos verbos no Present Simple. Atenção às frases negativas — revise a estrutura 'don't / doesn't'...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _sendingFeedback
                        ? null
                        : () => _sendPackageFeedback(item),
                    icon: _sendingFeedback
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      'Enviar Feedback do Pacote',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExercisePackageRow({
    required int index,
    required Map<String, dynamic> qf,
    required String defaultTitle,
    required ColorScheme colors,
  }) {
    final isCorrect = qf['correct'] == true;
    final title = qf['question']?.toString().trim().isNotEmpty == true
        ? qf['question'].toString()
        : '$defaultTitle - Questão ${index + 1}';
    final hasAi = '${qf['generatedBy'] ?? qf['source'] ?? ''}'
        .toUpperCase()
        .contains('AI') ||
        title.toLowerCase().contains('ia');
    final scoreText = isCorrect ? '1/1' : '0/1';
    final percentVal = isCorrect ? 1.0 : 0.0;
    final percentLabel = isCorrect ? '100% de acerto' : '0% de acerto';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (hasAi) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 11,
                              color: Color(0xFF7C3AED),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'IA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                scoreText,
                style: const TextStyle(
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentVal,
              minHeight: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                percentLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (qf['studentAnswer'] != null)
                Text(
                  'Resp.: ${qf['studentAnswer']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSubmissionDate(dynamic rawDate) {
    if (rawDate == null) return 'Data recente';
    try {
      final dt = DateTime.parse(rawDate.toString());
      final y = dt.year;
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $h:$min';
    } catch (_) {
      return rawDate.toString();
    }
  }

  Future<void> _sendPackageFeedback(Map<String, dynamic> item) async {
    final text = _packageFeedbackCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um feedback antes de enviar.')),
      );
      return;
    }
    setState(() => _sendingFeedback = true);
    try {
      await _dio.patch(
        '/api/exercises/submissions/${item['id']}/feedback',
        data: {
          'feedback': text,
          'correctCount': item['correctCount'],
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback do pacote enviado com sucesso!'),
          ),
        );
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingFeedback = false);
    }
  }

  String _reviewStatusLabel(Map<String, dynamic> item) {
    final status = '${item['reviewStatus'] ?? ''}'.toUpperCase();
    if (status == 'PENDING_REVIEW') {
      return 'Aguardando revisão manual (questão aberta)';
    }
    if (status == 'REVIEWED' || item['reviewedAt'] != null) {
      return 'Revisada pelo professor';
    }
    return 'Corrigida automaticamente';
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
    final controller = TextEditingController(
      text: submission['feedback']?.toString() ?? '',
    );
    final questionCount =
        (submission['questionCount'] as num?)?.toInt() ?? 1;
    var selectedCorrect =
        ((submission['correctCount'] as num?)?.toInt() ?? 0).clamp(
          0,
          questionCount,
        );
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(
              'Revisar entrega de ${submission['studentName'] ?? 'estudante'}',
            ),
            content: SizedBox(
              width: responsiveDialogWidth(ctx, maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedCorrect,
                    decoration: InputDecoration(
                      labelText:
                          'Questões corretas (de $questionCount no total)',
                      border: const OutlineInputBorder(),
                    ),
                    items: List.generate(
                      questionCount + 1,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text(
                          '$index / $questionCount correta(s)',
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedCorrect = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Comentário pedagógico para o estudante',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Salvar revisão'),
              ),
            ],
          ),
        ),
      );
      if (ok == true && controller.text.trim().isNotEmpty) {
        await _dio.patch(
          '/api/exercises/submissions/${submission['id']}/feedback',
          data: {
            'feedback': controller.text.trim(),
            'correctCount': selectedCorrect,
          },
        );
        await _refresh();
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_parseError(error))));
    } finally {
      Future.delayed(const Duration(milliseconds: 400), controller.dispose);
    }
  }
}

class _LearningFeaturePageState extends State<LearningFeaturePage> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _load;
  List<_Exercise> _exercises = [];
  List<_Submission> _submissions = [];
  List<Map<String, dynamic>> _dbAchievements = [];
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
    _dbAchievements = [];
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
      } else if (widget.section == 'achievements') {
        final responses = await Future.wait([
          _dio.get('/api/exercises/submissions'),
          _dio.get('/api/achievements/me').catchError(
            (_) => Response(requestOptions: RequestOptions(), data: const []),
          ),
        ]);
        _submissions = (responses[0].data as List)
            .map(
              (item) => _Submission.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        _dbAchievements = (responses[1].data as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      } else if (widget.section == 'history') {
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
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              leading: Icon(
                item.reviewStatus == 'PENDING_REVIEW'
                    ? Icons.hourglass_top_rounded
                    : Icons.history_rounded,
                color: item.reviewStatus == 'PENDING_REVIEW'
                    ? const Color(0xFFD97706)
                    : null,
              ),
              title: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${item.language} · ${item.correct}/${item.count} corretas · ${item.reviewStatusLabel}${item.feedback == null ? '' : '\nFeedback do professor: ${item.feedback}'}',
              ),
              trailing: Text(
                '+${item.xp} XP',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              children: [
                if (item.questionFeedback.isNotEmpty)
                  for (final qf in item.questionFeedback)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        qf['evaluationMode'] == 'OPEN_ENDED'
                            ? Icons.subject_rounded
                            : (qf['correct'] == true
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.cancel_outlined),
                        color: qf['evaluationMode'] == 'OPEN_ENDED'
                            ? const Color(0xFFD97706)
                            : (qf['correct'] == true
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626)),
                      ),
                      title: Text(
                        'Questão ${((qf['questionIndex'] as num?)?.toInt() ?? 0) + 1}: ${qf['question'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Sua resposta: ${qf['studentAnswer'] ?? ''}\n'
                        '${qf['feedback'] ?? ''}',
                      ),
                    )
                else
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Sem detalhes individuais para esta entrega.'),
                  ),
              ],
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
      padding: responsivePagePadding(context),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.primary, colors.primary.withValues(alpha: .86)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: responsiveCardPadding(context),
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
                const SizedBox(height: 20),
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
    final achievements = _buildAchievements(_submissions, _dbAchievements);

    final earned = achievements.where((item) => item.earned).length;
    final progress = achievements.isEmpty ? 0.0 : earned / achievements.length;
    final grouped = <String, List<_AchievementMilestone>>{};
    for (final achievement in achievements) {
      grouped.putIfAbsent(achievement.category, () => []).add(achievement);
    }
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: responsivePagePadding(context),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.primary, colors.primary.withValues(alpha: .86)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: responsiveCardPadding(context),
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 11,
                                backgroundColor: Colors.white.withValues(alpha: 0.25),
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (dataLoadError != null ||
                    (_submissions.isEmpty && _dbAchievements.isEmpty)) ...[
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
  Map<String, dynamic>? _recapResult;
  bool _saving = false;
  bool _listening = false;
  bool _audioFallbackMode = false;
  String? _speechStatus;
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
    AudioSpeechHelper.stopSpeaking();
    _text.dispose();
    super.dispose();
  }

  Future<void> _speakCurrentPrompt({double rate = 1.0}) async {
    final q = widget.exercise.questions[_index];
    final targetText = q.spokenReference.isNotEmpty
        ? q.spokenReference
        : q.prompt;
    final ok = await AudioSpeechHelper.speak(
      targetText,
      languageName: widget.exercise.language,
      rate: rate,
    );
    if (!ok && mounted) {
      setState(() {
        _audioFallbackMode = true;
        _speechStatus =
            'Síntese de áudio indisponível neste dispositivo. Modo acessível ativado automaticamente.';
      });
    }
  }

  Future<void> _listenMicrophone() async {
    if (_listening) return;
    setState(() {
      _listening = true;
      _speechStatus = 'Solicitando acesso ao microfone...';
    });
    try {
      final transcript = await AudioSpeechHelper.recognizeSpeech(
        languageName: widget.exercise.language,
        onStatus: (status) {
          if (mounted) {
            setState(() => _speechStatus = status);
          }
        },
      );
      if (!mounted) return;
      if (transcript != null && transcript.isNotEmpty) {
        setState(() {
          _text.text = transcript;
          final q = widget.exercise.questions[_index];
          if (q.options.isNotEmpty) {
            for (final opt in q.options) {
              if (opt.trim().toLowerCase() == transcript.trim().toLowerCase()) {
                _selected[_index] = opt;
                break;
              }
            }
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _listening = false);
      }
    }
  }

  void _next() {
    final q = widget.exercise.questions[_index];
    final answer = q.options.isEmpty
        ? _text.text.trim()
        : (_selected[_index] ?? _text.text.trim());
    if (answer.isEmpty) return;
    _answers[_index] = answer;
    if (_index < widget.exercise.questions.length - 1) {
      setState(() {
        _index++;
        _speechStatus = null;
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
      setState(() {
        _recapResult = result;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_parseError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildRecapScreen(BuildContext context, Map<String, dynamic> result) {
    final colors = Theme.of(context).colorScheme;
    final int correct = (result['correctCount'] as num?)?.toInt() ?? 0;
    final int total =
        (result['questionCount'] as num?)?.toInt() ??
        (widget.exercise.questions.isNotEmpty
            ? widget.exercise.questions.length
            : 1);
    final int safeTotal = total <= 0 ? 1 : total;
    final int percent = ((correct / safeTotal) * 100).round();
    final int xpEarned =
        (result['xpEarned'] as num?)?.toInt() ?? (correct * 10);
    final String reviewStatus = '${result['reviewStatus'] ?? 'AUTO_GRADED'}';
    final List<Map<String, dynamic>> questionFeedback =
        ((result['questionFeedback'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: responsivePagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Blue Top Banner (Parabéns / Troféu)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFFD700),
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Parabéns!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Você completou o exercício',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Score Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        '$correct/$total',
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Respostas Corretas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Aproveitamento',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (percent / 100.0).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 4 Stat Tiles in a row
                      LayoutBuilder(
                        builder: (context, box) {
                          final isNarrow = box.maxWidth < 520;
                          final tiles = [
                            _buildRecapStatTile(
                              icon: Icons.bolt_rounded,
                              iconColor: const Color(0xFF16A34A),
                              bgColor: const Color(0xFFF0FDF4),
                              label: 'XP Ganho',
                              value: '+$xpEarned',
                              valueColor: const Color(0xFF16A34A),
                            ),
                            _buildRecapStatTile(
                              icon: Icons.trending_up_rounded,
                              iconColor: const Color(0xFFEA580C),
                              bgColor: const Color(0xFFFFF7ED),
                              label: 'Sequência',
                              value: 'Mantida!',
                              valueColor: const Color(0xFFEA580C),
                            ),
                            _buildRecapStatTile(
                              icon: Icons.military_tech_rounded,
                              iconColor: const Color(0xFF9333EA),
                              bgColor: const Color(0xFFFAF5FF),
                              label: 'Conquista',
                              value: '$percent% de Acerto!',
                              valueColor: const Color(0xFF9333EA),
                            ),
                            _buildRecapStatTile(
                              icon: Icons.arrow_upward_rounded,
                              iconColor: const Color(0xFF2563EB),
                              bgColor: const Color(0xFFEFF6FF),
                              label: 'Ranking',
                              value: '#5 ▲ 2 pos.',
                              valueColor: const Color(0xFF2563EB),
                            ),
                          ];

                          if (isNarrow) {
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: tiles
                                  .map(
                                    (t) => SizedBox(
                                      width: (box.maxWidth - 10) / 2,
                                      child: t,
                                    ),
                                  )
                                  .toList(),
                            );
                          }
                          return Row(
                            children: tiles
                                .map(
                                  (t) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: t,
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                      if (reviewStatus == 'PENDING_REVIEW') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                color: Color(0xFFB45309),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Esta atividade inclui questões discursivas/abertas e aguarda revisão final do seu professor.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section: Revisão das Questões
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Revisão das Questões',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (
                        var i = 0;
                        i < widget.exercise.questions.length;
                        i++
                      ) ...[
                        _buildRecapQuestionTile(
                          index: i,
                          question: widget.exercise.questions[i],
                          questionFeedback: questionFeedback,
                          colors: colors,
                        ),
                        if (i < widget.exercise.questions.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bottom Continue Button
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: widget.onFinished,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecapStatTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecapQuestionTile({
    required int index,
    required _ExerciseQuestion question,
    required List<Map<String, dynamic>> questionFeedback,
    required ColorScheme colors,
  }) {
    final qf = questionFeedback.firstWhere(
      (item) => ((item['questionIndex'] as num?)?.toInt() ?? -1) == index,
      orElse: () => <String, dynamic>{},
    );
    final studentAns = (index < _answers.length && _answers[index].isNotEmpty)
        ? _answers[index]
        : (qf['studentAnswer']?.toString() ?? '');
    final bool isCorrect =
        qf['correct'] == true ||
        (qf['evaluationMode'] != 'OPEN_ENDED' &&
            studentAns.trim().isNotEmpty &&
            studentAns.trim().toLowerCase() ==
                question.answer.trim().toLowerCase());

    final cardBg =
        isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final borderColor =
        isCorrect ? const Color(0xFF86EFAC) : const Color(0xFFFECACA);
    final iconColor =
        isCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final ansColor =
        isCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCorrect
                    ? Icons.check_circle_outline_rounded
                    : Icons.cancel_outlined,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.prompt,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'Sua resposta: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(
                        text: studentAns.isEmpty
                            ? '(Sem resposta)'
                            : studentAns,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ansColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCorrect && question.answer.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Resposta correta: ${question.answer.trim()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_recapResult != null) {
      return _buildRecapScreen(context, _recapResult!);
    }
    if (widget.exercise.questions.isEmpty)
      return _EmptyPanel(
        title: 'Atividade sem questões',
        message: 'Peça ao professor para atualizar esta atividade.',
        onRefresh: widget.onBack,
      );
    final q = widget.exercise.questions[_index];
    final isAudio = q.isAudioQuestion(widget.exercise.category);
    final isOpenEnded = q.isOpenEnded;
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: responsivePagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Voltar',
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      q.style,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${_index + 1}/${widget.exercise.questions.length}'),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (_index + 1) / widget.exercise.questions.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      q.prompt,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Ouvir enunciado em ${widget.exercise.language}',
                    onPressed: () => _speakCurrentPrompt(rate: 1.0),
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isAudio || _audioFallbackMode) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.headphones_rounded, color: colors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Exercício com Áudio e Pronúncia (${widget.exercise.language})',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _speakCurrentPrompt(rate: 1.0),
                            icon: const Icon(Icons.volume_up_rounded, size: 18),
                            label: const Text('Ouvir frase'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _speakCurrentPrompt(rate: 0.65),
                            icon: const Icon(Icons.slow_motion_video_rounded, size: 18),
                            label: const Text('Ouvir devagar'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _listening ? null : _listenMicrophone,
                            icon: Icon(
                              _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _listening
                                  ? 'Ouvindo microfone...'
                                  : 'Falar / Transcrever',
                            ),
                          ),
                        ],
                      ),
                      if (_speechStatus != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _speechStatus!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() {
                            _audioFallbackMode = !_audioFallbackMode;
                          }),
                          icon: Icon(
                            _audioFallbackMode
                                ? Icons.hearing_rounded
                                : Icons.hearing_disabled_rounded,
                            size: 16,
                          ),
                          label: Text(
                            _audioFallbackMode
                                ? 'Modo acessível por texto ativo (ocultar transcrição)'
                                : 'Não posso ouvir ou falar agora (usar alternativa acessível)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      if (_audioFallbackMode && q.spokenReference.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Transcrição acessível do áudio: "${q.spokenReference}"',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (isOpenEnded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Questão aberta/discursiva: escreva sua resposta com suas próprias palavras. Ela será avaliada por critérios/rubrica e ficará disponível para revisão do professor.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              if (q.options.isEmpty || _audioFallbackMode || isAudio)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextField(
                    controller: _text,
                    autofocus: q.options.isEmpty,
                    maxLines: isOpenEnded ? 4 : 2,
                    minLines: isOpenEnded ? 3 : 1,
                    decoration: InputDecoration(
                      labelText: isAudio
                          ? 'Transcrição da sua fala ou resposta escrita'
                          : (isOpenEnded
                                ? 'Sua resposta discursiva'
                                : 'Sua resposta'),
                      border: const OutlineInputBorder(),
                    ),
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
              const SizedBox(height: 24),
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
  const _ExerciseQuestion(
    this.prompt,
    this.options, {
    this.style = 'Múltipla escolha',
    this.answer = '',
  });
  final String prompt;
  final List<String> options;
  final String style;
  final String answer;

  String get spokenReference => answer.trim().isNotEmpty ? answer.trim() : prompt.trim();

  bool get isOpenEnded {
    final s = style.trim().toLowerCase();
    return s.contains('discursiva') ||
        s.contains('aberta') ||
        s.contains('redação') ||
        s.contains('livre');
  }

  bool isAudioQuestion(String exerciseCategory) {
    final s = style.trim().toLowerCase();
    final c = exerciseCategory.trim().toLowerCase();
    final p = prompt.trim().toLowerCase();
    return s.contains('áudio') ||
        s.contains('audio') ||
        s.contains('pronúncia') ||
        s.contains('pronuncia') ||
        c.contains('pronúncia') ||
        c.contains('pronuncia') ||
        c.contains('áudio') ||
        c.contains('audio') ||
        p.contains('ouça') ||
        p.contains('pronuncie') ||
        p.contains('repita em voz alta');
  }

  factory _ExerciseQuestion.fromJson(Map<String, dynamic> json) =>
      _ExerciseQuestion(
        json['question'] as String? ?? '',
        (json['options'] as List? ?? [])
            .map((item) => item.toString())
            .toList(),
        style: json['style'] as String? ?? 'Múltipla escolha',
        answer: json['answer'] as String? ?? '',
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
    this.reviewStatus = 'AUTO_GRADED',
    this.questionFeedback = const [],
  });
  final int exerciseId;
  final String title, language;
  final int correct, count, xp;
  final String? feedback;
  final DateTime? submittedAt;
  final String reviewStatus;
  final List<Map<String, dynamic>> questionFeedback;

  String get reviewStatusLabel {
    final status = reviewStatus.toUpperCase();
    if (status == 'PENDING_REVIEW') {
      return 'Aguardando revisão do professor';
    }
    if (status == 'REVIEWED') {
      return 'Revisada pelo professor';
    }
    return 'Corrigida automaticamente';
  }

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
    reviewStatus: json['reviewStatus'] as String? ?? 'AUTO_GRADED',
    questionFeedback: (json['questionFeedback'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(),
  );
}

IconData _achievementIconFromName(String? iconName) {
  return switch (iconName?.trim()) {
    'local_fire_department_rounded' => Icons.local_fire_department_rounded,
    'star_rounded' => Icons.star_rounded,
    'bolt_rounded' => Icons.bolt_rounded,
    'menu_book_rounded' => Icons.menu_book_rounded,
    'gps_fixed_rounded' => Icons.gps_fixed_rounded,
    'translate_rounded' => Icons.translate_rounded,
    'groups_rounded' => Icons.groups_rounded,
    'chat_bubble_outline_rounded' => Icons.chat_bubble_outline_rounded,
    'workspace_premium_rounded' => Icons.workspace_premium_rounded,
    _ => Icons.emoji_events_rounded,
  };
}

List<_AchievementMilestone> _buildAchievements(
  List<_Submission> submissions, [
  List<Map<String, dynamic>> dbAchievements = const [],
]) {
  if (dbAchievements.isNotEmpty) {
    return dbAchievements.map((item) {
      final earned = item['earned'] == true;
      final parsedDate = DateTime.tryParse(item['earnedAt']?.toString() ?? '')?.toLocal();
      return _AchievementMilestone(
        category: item['category']?.toString() ?? 'Geral',
        title: item['title']?.toString() ?? 'Conquista',
        description: item['description']?.toString() ?? '',
        icon: _achievementIconFromName(item['iconName']?.toString()),
        earnedAt: earned ? (parsedDate ?? DateTime.now()) : null,
      );
    }).toList();
  }
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
  const StudentLanguageManager({
    super.key,
    this.data,
    this.student,
    this.onChanged,
  });

  final DashboardData? data;
  final StudentProfile? student;
  final VoidCallback? onChanged;

  @override
  State<StudentLanguageManager> createState() => _StudentLanguageManagerState();
}

class _StudentLanguageManagerState extends State<StudentLanguageManager> {
  static const List<String> _levels = ['Básico', 'Intermediário', 'Avançado'];

  StudentProfile? get _profile => widget.student ?? widget.data?.studentProfile;

  Future<void> _openEditorDialog(BuildContext context) async {
    final profile = _profile;
    if (profile?.id == null) return;
    final nameCtrl = TextEditingController();
    String selectedLevel = _levels.first;
    bool busy = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Adicionar ou editar idioma'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Idioma'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedLevel,
                decoration: const InputDecoration(labelText: 'Proficiência'),
                items: _levels
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => selectedLevel = v ?? selectedLevel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setDialogState(() => busy = true);
                      try {
                        final languages = [
                          ...profile!.languages.map((v) {
                            final parts = v.split(':');
                            final rawLvl = parts.length > 1
                                ? parts.last.trim()
                                : 'Básico';
                            return {
                              'languageName': parts.first.trim(),
                              'level': _levels.contains(rawLvl)
                                  ? rawLvl
                                  : 'Básico',
                              'score': 0,
                            };
                          }),
                        ];
                        final existing = languages.indexWhere(
                          (v) =>
                              (v['languageName'] as String).toLowerCase() ==
                              nameCtrl.text.trim().toLowerCase(),
                        );
                        final item = {
                          'languageName': nameCtrl.text.trim(),
                          'level': selectedLevel,
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
                            'gender': profile.gender,
                            'googleId': profile.googleId,
                            'languages': languages,
                          },
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        if (ctx.mounted) showLearningError(ctx, e);
                      } finally {
                        if (ctx.mounted) setDialogState(() => busy = false);
                      }
                    },
              child: Text(busy ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 400), nameCtrl.dispose);

    if (saved == true) {
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.student != null || widget.onChanged != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _profile?.id == null
              ? null
              : () => _openEditorDialog(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Adicionar ou editar idioma'),
        ),
      );
    }
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Adicionar ou editar idioma'),
      content: const Text('Use o botão de idiomas no painel do estudante.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

class StudentClassesView extends StatefulWidget {
  const StudentClassesView({
    super.key,
    required this.data,
    required this.onRefresh,
  });
  final DashboardData data;
  final VoidCallback onRefresh;

  @override
  State<StudentClassesView> createState() => _StudentClassesViewState();
}

class _StudentClassesViewState extends State<StudentClassesView> {
  StudentEnrollment? _selectedEnrollment;

  @override
  Widget build(BuildContext context) {
    if (_selectedEnrollment != null) {
      return _StudentClassDashboardView(
        enrollment: _selectedEnrollment!,
        data: widget.data,
        onBack: () => setState(() => _selectedEnrollment = null),
        onRefresh: widget.onRefresh,
      );
    }

    final activeEnrollments = widget.data.studentEnrollments
        .where((e) => e.isActive)
        .toList();
    final pastEnrollments = widget.data.studentEnrollments
        .where((e) => !e.isActive)
        .toList();

    return ListView(
      padding: responsivePagePadding(context),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Minhas turmas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            OutlinedButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Atualizar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Acesse o painel completo da sua turma para ver seu rendimento, colegas de classe e atividades com prazos.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        if (widget.data.studentEnrollments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Você ainda não possui turmas cadastradas. Aguarde seu professor adicioná-lo a uma turma.',
              ),
            ),
          ),
        if (activeEnrollments.isNotEmpty) ...[
          const Text(
            'Turmas Ativas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...activeEnrollments.map(
            (e) => _DetailedEnrollmentCard(
              enrollment: e,
              onTap: () => setState(() => _selectedEnrollment = e),
              onRefresh: widget.onRefresh,
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (pastEnrollments.isNotEmpty) ...[
          const Text(
            'Turmas Anteriores / Histórico',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Turmas encerradas ou das quais você já fez parte. As estatísticas refletem seu desempenho até a data de encerramento.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          ...pastEnrollments.map(
            (e) => _DetailedEnrollmentCard(
              enrollment: e,
              onTap: () => setState(() => _selectedEnrollment = e),
              onRefresh: widget.onRefresh,
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailedEnrollmentCard extends StatelessWidget {
  const _DetailedEnrollmentCard({
    required this.enrollment,
    required this.onTap,
    required this.onRefresh,
  });

  final StudentEnrollment enrollment;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isActive = enrollment.isActive;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive ? Icons.groups_rounded : Icons.history_edu_rounded,
                  color: isActive ? const Color(0xFF2563EB) : Colors.grey[700],
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            enrollment.schoolClassName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF15803D).withValues(alpha: 0.12)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isActive ? 'Ativa' : 'Encerrada',
                            style: TextStyle(
                              color: isActive ? const Color(0xFF15803D) : Colors.grey[800],
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isActive
                          ? 'Matriculado em ${enrollment.enrollmentDate}'
                          : 'Encerrada em ${enrollment.cancellationDate ?? enrollment.enrollmentDate} · Histórico preservado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.dashboard_customize_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Clique para ver acertos, colegas e atividades',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isActive)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'Opções da matrícula',
                  onSelected: (v) async {
                    try {
                      if (v == 'cancel') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Cancelar matrícula?'),
                            content: const Text(
                              'Tem certeza de que deseja solicitar o cancelamento desta matrícula?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Voltar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                                child: const Text('Cancelar Matrícula'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && enrollment.id != null) {
                          await ApiClient().dio.post(
                            '${AppConfig.apiBaseUrl}/api/enrollments/${enrollment.id}/cancel',
                          );
                          onRefresh();
                        }
                      }
                    } catch (e) {
                      if (context.mounted) showLearningError(context, e);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancelar matrícula'),
                    ),
                  ],
                ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentClassDashboardView extends StatefulWidget {
  const _StudentClassDashboardView({
    required this.enrollment,
    required this.data,
    required this.onBack,
    required this.onRefresh,
  });

  final StudentEnrollment enrollment;
  final DashboardData data;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  State<_StudentClassDashboardView> createState() =>
      _StudentClassDashboardViewState();
}

class _StudentClassDashboardViewState
    extends State<_StudentClassDashboardView> {
  final Dio _dio = ApiClient().dio;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _mySubmissions = [];
  int _activeTab = 0; // 0: Colegas, 1: Atividades
  String _classmateSort = 'xp'; // 'xp', 'accuracy', 'name'

  @override
  void initState() {
    super.initState();
    _loadClassData();
  }

  Future<void> _loadClassData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      int? classId = widget.enrollment.schoolClassId;
      if (classId == null) {
        final classesResp = await _dio.get<List<dynamic>>(
          '${AppConfig.apiBaseUrl}/api/classes',
        );
        final list = classesResp.data ?? const [];
        for (final item in list) {
          if (item is Map &&
              item['name']?.toString() == widget.enrollment.schoolClassName) {
            classId = (item['id'] as num?)?.toInt();
            break;
          }
        }
      }

      if (classId == null) {
        throw Exception('Turma não localizada no banco de dados.');
      }

      final respDash = await _dio.get(
        '${AppConfig.apiBaseUrl}/api/classes/$classId/dashboard',
      );
      final respSubs = await _dio.get(
        '${AppConfig.apiBaseUrl}/api/exercises/submissions',
      );

      if (!mounted) return;
      setState(() {
        _dashboard = respDash.data is Map ? Map<String, dynamic>.from(respDash.data as Map) : null;
        final rawSubs = respSubs.data;
        _mySubmissions = (rawSubs is List ? rawSubs : const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = parseLearningError(e);
        _isLoading = false;
      });
    }
  }

  bool _isCriticalDeadline(String? dueDateStr) {
    if (dueDateStr == null || dueDateStr.isEmpty) return false;
    final dueDate = DateTime.tryParse(dueDateStr);
    if (dueDate == null) return false;
    final deadline = dueDate.hour == 0 && dueDate.minute == 0
        ? DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59, 59)
        : dueDate;
    final diff = deadline.difference(DateTime.now());
    return diff.inSeconds <= 86400; // less than 24h or overdue
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _dashboard == null) {
      return ListView(
        padding: responsivePagePadding(context),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              const Text('Voltar para Minhas Turmas'),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFDC2626)),
                  const SizedBox(height: 12),
                  Text(_error ?? 'Não foi possível carregar os dados da turma.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadClassData,
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final dash = _dashboard!;
    final currentStudentId = widget.data.studentProfile?.id;
    final studentsList = (dash['students'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    Map<String, dynamic>? myStudentSummary;
    for (final s in studentsList) {
      if (currentStudentId != null &&
          (s['studentId'] as num?)?.toInt() == currentStudentId) {
        myStudentSummary = s;
        break;
      }
    }
    myStudentSummary ??= studentsList.isNotEmpty ? studentsList.first : null;

    final myAccuracy =
        (myStudentSummary?['averageAccuracyPercent'] as num?)?.toDouble() ?? 0.0;
    final myXp = (myStudentSummary?['xpEarned'] as num?)?.toInt() ?? 0;
    final mySubmissionsCount =
        (myStudentSummary?['submissionsCount'] as num?)?.toInt() ?? 0;

    final exercisesList = (dash['exercises'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // Map my submissions by exerciseId
    final Map<int, Map<String, dynamic>> mySubsByExerciseId = {};
    for (final sub in _mySubmissions) {
      final exId = (sub['exerciseId'] as num?)?.toInt();
      if (exId != null) {
        mySubsByExerciseId[exId] = sub;
      }
    }

    // Sort classmates
    final sortedClassmates = List<Map<String, dynamic>>.from(studentsList);
    if (_classmateSort == 'xp') {
      sortedClassmates.sort((a, b) => ((b['xpEarned'] as num?)?.toInt() ?? 0)
          .compareTo((a['xpEarned'] as num?)?.toInt() ?? 0));
    } else if (_classmateSort == 'accuracy') {
      sortedClassmates.sort((a, b) =>
          ((b['averageAccuracyPercent'] as num?)?.toDouble() ?? 0.0).compareTo(
              (a['averageAccuracyPercent'] as num?)?.toDouble() ?? 0.0));
    } else {
      sortedClassmates.sort((a, b) => '${a['name'] ?? ''}'
          .toLowerCase()
          .compareTo('${b['name'] ?? ''}'.toLowerCase()));
    }

    final isPast = !widget.enrollment.isActive;

    return ListView(
      padding: responsivePagePadding(context),
      children: [
        // Botão voltar e Título
        Row(
          children: [
            IconButton(
              tooltip: 'Voltar para Minhas Turmas',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dash['name']?.toString() ?? widget.enrollment.schoolClassName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    [
                      if (dash['schoolName'] != null) '${dash['schoolName']}',
                      if (dash['institutionName'] != null)
                        '${dash['institutionName']}',
                      if (dash['schoolYear'] != null)
                        'Ano ${dash['schoolYear']}',
                      if (dash['shift'] != null) '${dash['shift']}',
                    ].join(' • '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Atualizar dados',
              onPressed: _loadClassData,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (isPast) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD97706).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.history_toggle_off_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Esta é uma turma anterior. Seus dados e métricas refletem exatamente o momento do desligamento (${widget.enrollment.cancellationDate ?? widget.enrollment.enrollmentDate}).',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 3 Cards de Métricas do Aluno
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 700 ? 3 : 1;
            final cardW = (constraints.maxWidth - (12 * (cols - 1))) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardW,
                  child: InfoStatCard(
                    title: 'Sua Taxa Média de Acertos',
                    value: '$myAccuracy%',
                    subtitle: 'Desempenho nesta turma',
                    icon: Icons.track_changes_rounded,
                    accentColor: const Color(0xFF2563EB),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: InfoStatCard(
                    title: 'Seu XP Ganho na Turma',
                    value: '$myXp XP',
                    subtitle: 'Total acumulado',
                    icon: Icons.bolt_rounded,
                    accentColor: const Color(0xFFFFB800),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: InfoStatCard(
                    title: 'Suas Entregas Realizadas',
                    value: '$mySubmissionsCount',
                    subtitle: 'Atividades submetidas',
                    icon: Icons.assignment_turned_in_rounded,
                    accentColor: const Color(0xFF059669),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // Tabs: Colegas de Turma / Atividades da Turma
        Row(
          children: [
            Expanded(
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Colegas da Turma (${sortedClassmates.length})'),
                    icon: const Icon(Icons.people_outline_rounded),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Atividades da Turma (${exercisesList.length})'),
                    icon: const Icon(Icons.assignment_outlined),
                  ),
                ],
                selected: {_activeTab},
                onSelectionChanged: (set) {
                  setState(() => _activeTab = set.first);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Conteúdo da Aba 0: Colegas da Turma
        if (_activeTab == 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Classificação dos Alunos',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ordenar por:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _classmateSort,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'xp',
                        child: Text('XP Acumulado'),
                      ),
                      DropdownMenuItem(
                        value: 'accuracy',
                        child: Text('Taxa de Acertos (%)'),
                      ),
                      DropdownMenuItem(
                        value: 'name',
                        child: Text('Ordem Alfabética'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _classmateSort = v);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sortedClassmates.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhum colega matriculado nesta turma.'),
              ),
            )
          else
            ...sortedClassmates.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final student = entry.value;
              final isMe = currentStudentId != null &&
                  (student['studentId'] as num?)?.toInt() == currentStudentId;
              final stAccuracy =
                  (student['averageAccuracyPercent'] as num?)?.toDouble() ?? 0.0;
              final stXp = (student['xpEarned'] as num?)?.toInt() ?? 0;
              final stSubs = (student['submissionsCount'] as num?)?.toInt() ?? 0;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isMe
                        ? const Color(0xFF2563EB).withValues(alpha: 0.5)
                        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
                    width: isMe ? 2 : 1,
                  ),
                ),
                color: isMe
                    ? const Color(0xFF2563EB).withValues(alpha: 0.04)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rank == 1
                              ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                              : (rank == 2
                                  ? const Color(0xFFC0C0C0).withValues(alpha: 0.2)
                                  : (rank == 3
                                      ? const Color(0xFFCD7F32).withValues(alpha: 0.2)
                                      : Colors.grey.withValues(alpha: 0.1))),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$rankº',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: rank == 1
                                ? const Color(0xFFB45309)
                                : Colors.grey[800],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  student['name']?.toString() ?? 'Estudante',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Você',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$stSubs entregas realizadas',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$stXp XP',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          Text(
                            'Acertos: $stAccuracy%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: stAccuracy >= 70
                                  ? const Color(0xFF15803D)
                                  : (stAccuracy >= 50
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],

        // Conteúdo da Aba 1: Atividades da Turma
        if (_activeTab == 1) ...[
          if (exercisesList.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhuma atividade cadastrada para esta turma.'),
              ),
            )
          else
            ...exercisesList.map((ex) {
              final exId = (ex['exerciseId'] as num?)?.toInt();
              final sub = exId != null ? mySubsByExerciseId[exId] : null;
              final isCompleted = sub != null;
              final dueDateStr = ex['dueDate']?.toString();
              final isCritical = !isCompleted && _isCriticalDeadline(dueDateStr);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isCompleted
                        ? const Color(0xFF15803D).withValues(alpha: 0.3)
                        : (isCritical
                            ? const Color(0xFFDC2626)
                            : Theme.of(context).colorScheme.outlineVariant),
                    width: isCritical ? 2 : 1,
                  ),
                ),
                color: isCritical
                    ? const Color(0xFFDC2626).withValues(alpha: 0.04)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? const Color(0xFF15803D).withValues(alpha: 0.12)
                                  : (isCritical
                                      ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                                      : const Color(0xFF2563EB).withValues(alpha: 0.12)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.check_circle_rounded
                                  : (isCritical
                                      ? Icons.alarm_on_rounded
                                      : Icons.assignment_outlined),
                              color: isCompleted
                                  ? const Color(0xFF15803D)
                                  : (isCritical
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF2563EB)),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex['title']?.toString() ?? 'Atividade',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (ex['languageName'] != null)
                                      '${ex['languageName']}',
                                    if (ex['proficiencyLevel'] != null)
                                      'Nível ${ex['proficiencyLevel']}',
                                  ].join(' • '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Badge de status
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF15803D).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Color(0xFF15803D),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Concluída (+${sub['xpEarned'] ?? 0} XP)',
                                    style: const TextStyle(
                                      color: Color(0xFF15803D),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (isCritical)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Faltam menos de 24h!',
                                    style: TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                dueDateStr != null
                                    ? 'Entrega até $dueDateStr'
                                    : 'Sem prazo fixo',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isCompleted && exId != null) ...[
                            OutlinedButton.icon(
                              onPressed: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) => _StudentExerciseReviewDialog(
                                    exerciseId: exId,
                                    exerciseTitle: ex['title']?.toString() ?? 'Atividade',
                                  ),
                                );
                              },
                              icon: const Icon(Icons.rate_review_outlined, size: 16),
                              label: const Text('Ver Correção & Respostas'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ],
    );
  }
}

class _StudentExerciseReviewDialog extends StatefulWidget {
  const _StudentExerciseReviewDialog({
    required this.exerciseId,
    required this.exerciseTitle,
  });

  final int exerciseId;
  final String exerciseTitle;

  @override
  State<_StudentExerciseReviewDialog> createState() =>
      _StudentExerciseReviewDialogState();
}

class _StudentExerciseReviewDialogState
    extends State<_StudentExerciseReviewDialog> {
  final Dio _dio = ApiClient().dio;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _exercise;
  Map<String, dynamic>? _submission;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview() async {
    try {
      final results = await Future.wait([
        _dio.get<Map<String, dynamic>>(
          '${AppConfig.apiBaseUrl}/api/exercises/${widget.exerciseId}',
        ),
        _dio.get<Map<String, dynamic>>(
          '${AppConfig.apiBaseUrl}/api/exercises/${widget.exerciseId}/my-submission',
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _exercise = results[0].data;
        _submission = results[1].data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = parseLearningError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fact_check_rounded,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Correção & Respostas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  widget.exerciseTitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 520,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _buildReviewContent(),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  Widget _buildReviewContent() {
    final sub = _submission!;
    final ex = _exercise!;
    final questions = (ex['questions'] as List? ?? const [])
        .whereType<Map>()
        .map((q) => Map<String, dynamic>.from(q))
        .toList();
    final studentAnswers = (sub['answers'] as List? ?? const [])
        .map((a) => a?.toString() ?? '')
        .toList();
    final questionResults = (sub['questionResults'] as List? ?? const [])
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final isReviewed = sub['reviewStatus'] == 'REVIEWED';
    final feedback = sub['feedback']?.toString();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de pontuação e status
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Acertos', style: TextStyle(fontSize: 12)),
                    Text(
                      '${sub['correctCount'] ?? 0} / ${sub['questionCount'] ?? questions.length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('XP Ganho', style: TextStyle(fontSize: 12)),
                    Text(
                      '+${sub['xpEarned'] ?? 0} XP',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Status da Avaliação', style: TextStyle(fontSize: 12)),
                    Text(
                      isReviewed ? 'Corrigido pelo Professor' : 'Avaliação Preliminar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isReviewed
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (feedback != null && feedback.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.rate_review_rounded,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Feedback do Professor:',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF5B21B6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          feedback,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Questões e Comparação com o Gabarito:',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < questions.length; i++) ...[
            _buildQuestionComparisonCard(
              index: i + 1,
              question: questions[i],
              studentAnswer: i < studentAnswers.length ? studentAnswers[i] : null,
              questionResult: i < questionResults.length ? questionResults[i] : null,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionComparisonCard({
    required int index,
    required Map<String, dynamic> question,
    required String? studentAnswer,
    required Map<String, dynamic>? questionResult,
  }) {
    final expected = question['correctAnswer'] ?? question['expectedAnswer'] ?? '';
    final isMatch = (studentAnswer ?? '').trim().toLowerCase() ==
        expected.toString().trim().toLowerCase();
    final status = questionResult?['status']?.toString().toUpperCase();
    final isCorrect = status == 'CORRECT' || (status == null && isMatch);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? const Color(0xFF15803D).withValues(alpha: 0.3)
              : const Color(0xFFDC2626).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor:
                    isCorrect ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                child: Icon(
                  isCorrect ? Icons.check : Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Questão $index: ${question['question'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isCorrect ? const Color(0xFF15803D) : const Color(0xFFDC2626))
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  'Sua resposta: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isCorrect
                        ? const Color(0xFF15803D)
                        : const Color(0xFFDC2626),
                  ),
                ),
                Expanded(
                  child: Text(
                    studentAnswer?.isEmpty ?? true ? '(em branco)' : studentAnswer!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCorrect
                          ? const Color(0xFF15803D)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (expected.toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text(
                    'Gabarito / Esperado: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$expected',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (questionResult?['message'] != null &&
              questionResult!['message'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Nota da avaliação: ${questionResult['message']}',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TeacherClassManagementView extends StatefulWidget {
  const TeacherClassManagementView({
    super.key,
    required this.data,
    required this.onRefresh,
  });
  final DashboardData data;
  final VoidCallback onRefresh;

  @override
  State<TeacherClassManagementView> createState() =>
      _TeacherClassManagementViewState();
}

class _TeacherClassManagementViewState
    extends State<TeacherClassManagementView> {
  int? _selectedClassId;
  String? _selectedClassName;
  bool _loadingDashboard = false;
  String? _dashboardError;
  Map<String, dynamic>? _classDashboard;

  Future<void> _create(BuildContext context) async {
    final name = TextEditingController();
    final year = TextEditingController(text: DateTime.now().year.toString());
    String shift = 'MANHÃ';
    final gradeCtrl = TextEditingController(text: 'Geral');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Criar turma na instituição'),
          content: SizedBox(
            width: responsiveDialogWidth(ctx, maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if ((widget.data.teacherProfile?.institution ?? '')
                    .isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B4CE2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.business_rounded,
                          size: 18,
                          color: Color(0xFF7B4CE2),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Instituição: ${widget.data.teacherProfile?.institution ?? ""}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome da turma'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: year,
                  decoration: const InputDecoration(labelText: 'Ano letivo'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: shift,
                  decoration: const InputDecoration(labelText: 'Turno'),
                  items: const [
                    DropdownMenuItem(value: 'MANHÃ', child: Text('Manhã')),
                    DropdownMenuItem(value: 'TARDE', child: Text('Tarde')),
                    DropdownMenuItem(value: 'NOITE', child: Text('Noite')),
                    DropdownMenuItem(
                      value: 'INTEGRAL',
                      child: Text('Integral'),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => shift = v ?? shift),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: gradeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nível / Série',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    final className = name.text.trim();
    final schoolYear = year.text.trim();
    final gradeLevel = gradeCtrl.text.trim().isEmpty
        ? 'Geral'
        : gradeCtrl.text.trim();

    Future.delayed(const Duration(milliseconds: 400), () {
      name.dispose();
      year.dispose();
      gradeCtrl.dispose();
    });

    if (result != true || className.isEmpty) return;

    try {
      await ApiClient().dio.post<Map<String, dynamic>>(
        '${AppConfig.apiBaseUrl}/api/classes/my-institution',
        data: {
          'name': className,
          'schoolYear': schoolYear.isEmpty
              ? DateTime.now().year.toString()
              : schoolYear,
          'shift': shift,
          'gradeLevel': gradeLevel,
          'active': true,
        },
      );
      widget.onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Turma criada e vinculada automaticamente à sua instituição!',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) showLearningError(context, e);
    }
  }

  Future<void> _openClassDashboard(int classId, String className) async {
    setState(() {
      _selectedClassId = classId;
      _selectedClassName = className;
      _loadingDashboard = true;
      _dashboardError = null;
    });
    try {
      final response = await ApiClient().dio.get<Map<String, dynamic>>(
        '${AppConfig.apiBaseUrl}/api/classes/$classId/dashboard',
      );
      if (!mounted) return;
      setState(() {
        _classDashboard = response.data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dashboardError = parseLearningError(e);
      });
    } finally {
      if (mounted) {
        setState(() => _loadingDashboard = false);
      }
    }
  }

  Future<void> _addStudentToClass(BuildContext context, int classId) async {
    final searchCtrl = TextEditingController();
    try {
      final response = await ApiClient().dio.get<List<dynamic>>(
        '${AppConfig.apiBaseUrl}/api/students',
      );
      final allStudents = (response.data ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!context.mounted) return;

      final selectedStudent = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            final q = searchCtrl.text.trim().toLowerCase();
            final filtered = allStudents.where((s) {
              if (q.isEmpty) return true;
              final n = '${s['name'] ?? ''}'.toLowerCase();
              final em = '${s['email'] ?? ''}'.toLowerCase();
              return n.contains(q) || em.contains(q);
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text('Adicionar estudante à turma'),
              content: SizedBox(
                width: responsiveDialogWidth(ctx, maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pesquisar estudante por nome ou e-mail',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 300,
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('Nenhum estudante encontrado.'),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, idx) {
                                final s = filtered[idx];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person_rounded),
                                  ),
                                  title: Text('${s['name'] ?? 'Estudante'}'),
                                  subtitle: Text('${s['email'] ?? ''}'),
                                  trailing: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                  ),
                                  onTap: () => Navigator.pop(ctx, s),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        ),
      );

      if (selectedStudent == null || !context.mounted) return;

      await ApiClient().dio.post(
        '${AppConfig.apiBaseUrl}/api/enrollments',
        data: {
          'studentId': selectedStudent['id'],
          'schoolClassId': classId,
          'enrollmentDate': DateTime.now().toIso8601String().substring(0, 10),
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selectedStudent['name']} adicionado(a) à turma com sucesso!',
            ),
          ),
        );
      }
      await _openClassDashboard(classId, _selectedClassName ?? 'Turma');
      widget.onRefresh();
    } catch (e) {
      if (context.mounted) showLearningError(context, e);
    } finally {
      Future.delayed(const Duration(milliseconds: 400), searchCtrl.dispose);
    }
  }

  Future<void> _updateEnrollmentStatus(
    int enrollmentId,
    String action,
    int classId,
  ) async {
    final newStatus = switch (action) {
      'approve' || 'resume' => 'ACTIVE',
      'suspend' => 'SUSPENDED',
      _ => 'CANCELLED',
    };
    try {
      await ApiClient().dio.put(
        '${AppConfig.apiBaseUrl}/api/enrollments/$enrollmentId/status',
        data: {'status': newStatus, 'notes': 'Atualizado pelo professor'},
      );
      await _openClassDashboard(classId, _selectedClassName ?? 'Turma');
      widget.onRefresh();
    } catch (e) {
      if (mounted) showLearningError(context, e);
    }
  }

  Widget _buildClassDashboardView(BuildContext context) {
    final classId = _selectedClassId!;
    final dash = _classDashboard;
    final totalStudents = (dash?['totalStudents'] as num?)?.toInt() ?? 0;
    final totalExercises = (dash?['totalExercises'] as num?)?.toInt() ?? 0;
    final totalSubmissions = (dash?['totalSubmissions'] as num?)?.toInt() ?? 0;
    final avgAccuracy =
        (dash?['averageAccuracyPercent'] as num?)?.toDouble() ?? 0.0;
    final avgCorrect =
        (dash?['averageCorrectAnswers'] as num?)?.toDouble() ?? 0.0;
    final avgQuestions =
        (dash?['averageQuestionsCount'] as num?)?.toDouble() ?? 0.0;
    final totalXp = (dash?['totalXpEarned'] as num?)?.toInt() ?? 0;
    final students = (dash?['students'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final exercises = (dash?['exercises'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return ListView(
      padding: responsivePagePadding(context),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Voltar para lista de turmas',
                  onPressed: () => setState(() {
                    _selectedClassId = null;
                    _classDashboard = null;
                  }),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dash?['name']?.toString() ??
                          _selectedClassName ??
                          'Dashboard da Turma',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [
                        if (dash?['institutionName'] != null)
                          '${dash!['institutionName']}',
                        if (dash?['schoolYear'] != null)
                          'Ano ${dash!['schoolYear']}',
                        if (dash?['shift'] != null) '${dash!['shift']}',
                        if (dash?['gradeLevel'] != null)
                          '${dash!['gradeLevel']}',
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _addStudentToClass(context, classId),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Adicionar Estudante'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openClassDashboard(
                    classId,
                    _selectedClassName ?? 'Turma',
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Atualizar'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_loadingDashboard)
          const Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_dashboardError != null)
          _ErrorPanel(
            message: _dashboardError!,
            onRetry: () =>
                _openClassDashboard(classId, _selectedClassName ?? 'Turma'),
          )
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final w = (constraints.maxWidth - (14 * (cols - 1))) / cols;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: w,
                    child: InfoStatCard(
                      title: 'Taxa Média de Acertos',
                      value: '${avgAccuracy.toStringAsFixed(1)}%',
                      subtitle:
                          'Média: ${avgCorrect.toStringAsFixed(1)} / ${avgQuestions.toStringAsFixed(1)} questões',
                      icon: Icons.gps_fixed_rounded,
                      accentColor: const Color(0xFF059669),
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: InfoStatCard(
                      title: 'Número de Alunos',
                      value: '$totalStudents',
                      subtitle: 'Estudantes vinculados à turma',
                      icon: Icons.groups_rounded,
                      accentColor: const Color(0xFF2563EB),
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: InfoStatCard(
                      title: 'Entregas & Atividades',
                      value: '$totalSubmissions',
                      subtitle: '$totalExercises atividade(s) publicada(s)',
                      icon: Icons.assignment_turned_in_rounded,
                      accentColor: const Color(0xFF7C3AED),
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: InfoStatCard(
                      title: 'XP Acumulado da Turma',
                      value: '$totalXp XP',
                      subtitle: 'Soma de XP das entregas',
                      icon: Icons.bolt_rounded,
                      accentColor: const Color(0xFFD97706),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Estudantes da Turma (${students.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (students.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nenhum estudante matriculado nesta turma ainda.',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _addStudentToClass(context, classId),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Adicionar primeiro aluno'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...students.map((s) {
              final enrollmentId = (s['enrollmentId'] as num?)?.toInt();
              final accuracy =
                  (s['averageAccuracyPercent'] as num?)?.toDouble() ?? 0.0;
              final subCount = (s['submissionsCount'] as num?)?.toInt() ?? 0;
              final xp = (s['xpEarned'] as num?)?.toInt() ?? 0;
              final gender = '${s['gender'] ?? ''}'.toUpperCase();
              final roleLabel = gender == 'FEMININO' ? 'Aluna' : 'Aluno';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(_initial(s['name'])),
                  ),
                  title: Text(
                    '${s['name'] ?? roleLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${s['email'] ?? ''} • $roleLabel • Status: ${s['status'] ?? 'ACTIVE'}\n'
                    'Entregas: $subCount • Média de acertos: ${accuracy.toStringAsFixed(1)}% • $xp XP',
                  ),
                  isThreeLine: true,
                  trailing: enrollmentId == null
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (action) => _updateEnrollmentStatus(
                            enrollmentId,
                            action,
                            classId,
                          ),
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
                ),
              );
            }),
          const SizedBox(height: 24),
          Text(
            'Atividades da Turma (${exercises.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (exercises.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhuma atividade publicada para esta turma.'),
              ),
            )
          else
            ...exercises.map((ex) {
              final avgExAcc =
                  (ex['averageAccuracyPercent'] as num?)?.toDouble() ?? 0.0;
              final subCount = (ex['submissionsCount'] as num?)?.toInt() ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.menu_book_rounded),
                  ),
                  title: Text(
                    '${ex['title'] ?? 'Atividade'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${ex['languageName'] ?? ''} • ${ex['proficiencyLevel'] ?? ''} • '
                    '$subCount entrega(s) • Média de acertos: ${avgExAcc.toStringAsFixed(1)}%',
                  ),
                ),
              );
            }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedClassId != null) {
      return _buildClassDashboardView(context);
    }

    return ListView(
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
        const SizedBox(height: 8),
        Text(
          'Clique em qualquer turma abaixo para abrir o dashboard completo com média de acertos, alunos e atividades.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.data.teacherAssignments.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Não há turmas atribuídas registradas no banco de dados. Atualize ou crie uma turma para começar.',
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: widget.onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
            ),
          ),
        ...widget.data.teacherAssignments.map(
          (a) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: a.schoolClassId == null
                  ? null
                  : () => _openClassDashboard(
                      a.schoolClassId!,
                      a.schoolClassName,
                    ),
              leading: const CircleAvatar(child: Icon(Icons.class_rounded)),
              title: Text(
                a.schoolClassName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Desde ${a.startDate} • Toque para abrir o Dashboard da Turma',
              ),
              trailing: FilledButton.tonalIcon(
                onPressed: a.schoolClassId == null
                    ? null
                    : () => _openClassDashboard(
                        a.schoolClassId!,
                        a.schoolClassName,
                      ),
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text('Dashboard'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
