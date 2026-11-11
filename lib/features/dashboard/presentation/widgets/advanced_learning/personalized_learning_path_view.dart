import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';

class PersonalizedLearningPathView extends StatefulWidget {
  const PersonalizedLearningPathView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<PersonalizedLearningPathView> createState() =>
      _PersonalizedLearningPathViewState();
}

class _PersonalizedLearningPathViewState
    extends State<PersonalizedLearningPathView> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _loadFuture;

  Map<String, dynamic>? _pathData;
  List<Map<String, dynamic>> _modules = [];
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadPath();
  }

  Future<void> _loadPath() async {
    setState(() => _error = null);
    try {
      final res = await _dio.get('/api/learning-path/me');
      if (!mounted) return;
      final data = Map<String, dynamic>.from(res.data as Map);
      setState(() {
        _pathData = data;
        _modules = ((data['modules'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Erro ao carregar trilha personalizada.');
    }
  }

  Future<void> _updateGoal(int minutes) async {
    try {
      final res = await _dio.put(
        '/api/learning-path/goals',
        data: {
          'language': _pathData?['language'] ?? 'Inglês',
          'dailyGoalMinutes': minutes,
          'targetCefrLevel': _pathData?['targetCefrLevel'] ?? 'B2',
        },
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      setState(() {
        _pathData = data;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meta diária ajustada para $minutes minutos.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar meta.')),
        );
      }
    }
  }

  Future<void> _completeModule(int moduleId) async {
    setState(() => _submitting = true);
    try {
      final res = await _dio.post(
        '/api/learning-path/modules/$moduleId/complete',
        queryParameters: {'scorePercent': 100.0},
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      setState(() {
        _pathData = data;
        _modules = ((data['modules'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _submitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Módulo concluído com sucesso! Próxima etapa desbloqueada.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _submitting = false);
    }
  }

  void _showDiagnosticDialog() async {
    List<Map<String, dynamic>> questions = [];
    try {
      final res = await _dio.get('/api/learning-path/diagnostic');
      questions = (res.data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar teste diagnóstico.')),
        );
      }
      return;
    }

    if (!mounted || questions.isEmpty) return;

    final answers = <int, int>{};
    int currentQIndex = 0;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = questions[currentQIndex];
          final qId = (q['id'] as num).toInt();
          final prompt = q['prompt'] ?? '';
          final category = q['category'] ?? '';
          final level = q['cefrLevel'] ?? '';
          final options = ((q['options'] as List?) ?? []).cast<String>();

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Teste Diagnóstico (${currentQIndex + 1}/${questions.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$level • $category',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(options.length, (optIdx) {
                  final isSelected = answers[qId] == optIdx;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Colors.blue.withValues(alpha: 0.12)
                            : null,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.blue
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () =>
                          setDialogState(() => answers[qId] = optIdx),
                      child: Text(
                        options[optIdx],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.blue.shade900
                              : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: answers[qId] == null || saving
                    ? null
                    : () async {
                        if (currentQIndex < questions.length - 1) {
                          setDialogState(() => currentQIndex++);
                        } else {
                          setDialogState(() => saving = true);
                          try {
                            final submitRes = await _dio.post(
                              '/api/learning-path/diagnostic',
                              data: {'language': 'Inglês', 'answers': answers},
                            );
                            final result = Map<String, dynamic>.from(
                              submitRes.data as Map,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            _loadPath();
                            if (mounted) {
                              _showResultModal(result);
                            }
                          } catch (e) {
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: Text(
                  currentQIndex < questions.length - 1
                      ? 'Próxima'
                      : 'Finalizar Teste',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResultModal(Map<String, dynamic> result) {
    final level = result['determinedCefrLevel'] ?? 'A2';
    final summary = result['diagnosticSummary'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: Colors.amber,
              size: 28,
            ),
            SizedBox(width: 8),
            Text('Resultado do Nivelamento'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF3579E8).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Nível CEFR: $level',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3579E8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              summary,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Iniciar Trilha'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: colors.error,
                ),
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: colors.error)),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _loadPath,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final cefr = _pathData?['currentCefrLevel'] ?? 'A1';
        final targetCefr = _pathData?['targetCefrLevel'] ?? 'B2';
        final streak = _pathData?['currentStreakDays'] ?? 1;
        final dailyGoal = _pathData?['dailyGoalMinutes'] ?? 15;
        final overallProgress =
            (_pathData?['overallProgressPercent'] as num?)?.toDouble() ?? 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trilha de Aprendizagem Personalizada',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Currículo adaptativo referenciado no Quadro Europeu Comum (CEFR) de A1 a C2.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _showDiagnosticDialog,
                    icon: const Icon(Icons.quiz_rounded, size: 18),
                    label: const Text('Fazer Teste de Nivelamento'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Overview Cards
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildCard(
                    title: 'Nível Atual',
                    value: '$cefr ➔ $targetCefr',
                    subtitle: 'Objetivo Alvo',
                    icon: Icons.flag_rounded,
                    color: const Color(0xFF3579E8),
                  ),
                  _buildCard(
                    title: 'Ofensiva Ativa',
                    value: '$streak dias',
                    subtitle: 'Sequência diária',
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.orange,
                  ),
                  _buildCard(
                    title: 'Progresso da Trilha',
                    value: '${overallProgress.toStringAsFixed(0)}%',
                    subtitle: 'Módulos concluídos',
                    icon: Icons.auto_graph_rounded,
                    color: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Daily Goal Selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: Colors.blueGrey),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meta Diária de Estudo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Defina um ritmo sustentável para seu aprendizado contínuo.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 5, label: Text('5m')),
                        ButtonSegment(value: 15, label: Text('15m')),
                        ButtonSegment(value: 30, label: Text('30m')),
                      ],
                      selected: {dailyGoal},
                      onSelectionChanged: (set) => _updateGoal(set.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Competence Matrix
              const Text(
                'Radar de Competências Linguísticas (CEFR)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildCompetenceGrid(colors),
              const SizedBox(height: 28),

              // Roadmap Modules
              const Text(
                'Módulos de Aprendizagem Progressivos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _modules.length,
                itemBuilder: (context, index) {
                  final m = _modules[index];
                  return _buildModuleTile(colors, m, index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompetenceGrid(ColorScheme colors) {
    final gram = (_pathData?['grammarCompetence'] as num?)?.toDouble() ?? 25.0;
    final voc =
        (_pathData?['vocabularyCompetence'] as num?)?.toDouble() ?? 30.0;
    final list =
        (_pathData?['listeningCompetence'] as num?)?.toDouble() ?? 20.0;
    final spk = (_pathData?['speakingCompetence'] as num?)?.toDouble() ?? 20.0;
    final read = (_pathData?['readingCompetence'] as num?)?.toDouble() ?? 35.0;
    final writ = (_pathData?['writingCompetence'] as num?)?.toDouble() ?? 25.0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildCompetenceBar('Gramática', gram, Colors.blue),
        _buildCompetenceBar('Vocabulário', voc, Colors.purple),
        _buildCompetenceBar('Audição (Listening)', list, Colors.teal),
        _buildCompetenceBar('Fala (Speaking)', spk, Colors.orange),
        _buildCompetenceBar('Leitura (Reading)', read, Colors.green),
        _buildCompetenceBar('Escrita (Writing)', writ, Colors.indigo),
      ],
    );
  }

  Widget _buildCompetenceBar(String label, double value, Color color) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value / 100.0,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTile(
    ColorScheme colors,
    Map<String, dynamic> m,
    int index,
  ) {
    final id = (m['moduleId'] as num).toInt();
    final title = m['title'] ?? '';
    final desc = m['description'] ?? '';
    final level = m['cefrLevel'] ?? 'A1';
    final category = m['category'] ?? '';
    final status = m['status'] ?? 'LOCKED';
    final isCompleted = status == 'COMPLETED';
    final isProgress = status == 'IN_PROGRESS';

    Color tileColor = isCompleted
        ? Colors.green
        : (isProgress ? const Color(0xFF3579E8) : Colors.grey);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isProgress ? const Color(0xFF3579E8) : colors.outlineVariant,
          width: isProgress ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: tileColor.withValues(alpha: 0.15),
              child: Icon(
                isCompleted
                    ? Icons.check_rounded
                    : (isProgress
                          ? Icons.play_arrow_rounded
                          : Icons.lock_rounded),
                color: tileColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          level,
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isProgress) ...[
              FilledButton.icon(
                onPressed: _submitting ? null : () => _completeModule(id),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Concluir Módulo'),
              ),
            ] else if (isCompleted) ...[
              const Icon(Icons.verified_rounded, color: Colors.green),
            ] else ...[
              Icon(Icons.lock_outline_rounded, color: colors.outline),
            ],
          ],
        ),
      ),
    );
  }
}
