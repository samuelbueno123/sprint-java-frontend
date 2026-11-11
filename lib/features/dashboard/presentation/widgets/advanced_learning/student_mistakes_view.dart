import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/network/api_client.dart';
import '../audio_speech_helper.dart';

class StudentMistakesView extends StatefulWidget {
  const StudentMistakesView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<StudentMistakesView> createState() => _StudentMistakesViewState();
}

class _StudentMistakesViewState extends State<StudentMistakesView> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _loadFuture;

  List<Map<String, dynamic>> _mistakes = [];
  Map<String, dynamic> _stats = {
    'unresolvedCount': 0,
    'resolvedCount': 0,
    'totalMistakes': 0,
  };
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _fetchMistakes();
  }

  Future<void> _fetchMistakes() async {
    try {
      final responses = await Future.wait([
        _dio.get('/api/students/me/mistakes'),
        _dio.get('/api/students/me/mistakes/stats'),
      ]);

      if (mounted) {
        setState(() {
          _mistakes = List<Map<String, dynamic>>.from(responses[0].data ?? []);
          _stats = Map<String, dynamic>.from(responses[1].data ?? {});
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar caderno de erros: $e')),
        );
      }
    }
  }

  Future<void> _reviewMistake(int mistakeId, bool isCorrect) async {
    setState(() => _isLoading = true);
    try {
      final res = await _dio.post(
        '/api/students/me/mistakes/$mistakeId/review',
        data: {'isCorrect': isCorrect},
      );

      final updated = Map<String, dynamic>.from(res.data);
      if (mounted) {
        setState(() {
          if (updated['resolved'] == true) {
            _mistakes.removeWhere((m) => m['id'] == mistakeId);
            _stats['unresolvedCount'] =
                ((_stats['unresolvedCount'] as int? ?? 1) - 1).clamp(0, 9999);
            _stats['resolvedCount'] =
                (_stats['resolvedCount'] as int? ?? 0) + 1;
          } else {
            final idx = _mistakes.indexWhere((m) => m['id'] == mistakeId);
            if (idx != -1) {
              _mistakes[idx] = updated;
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isCorrect
                ? const Color(0xFF16A34A)
                : Colors.orange.shade800,
            content: Text(
              updated['resolved'] == true
                  ? '🎉 Questão dominada com sucesso! +10 XP concedidos.'
                  : (isCorrect
                        ? 'Muito bem! Acerte mais 1 vez para dominar este item.'
                        : 'Resposta incorreta. Continue praticando para dominar.'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao registrar revisão: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAiExplanationDialog(Map<String, dynamic> mistake) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AiExplanationDialog(mistake: mistake, dio: _dio),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Caderno de Erros Inteligente'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: () {
              setState(() {
                _loadFuture = _fetchMistakes();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final unresolved = _stats['unresolvedCount'] ?? _mistakes.length;
          final resolved = _stats['resolvedCount'] ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Summary Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF7F1D1D), const Color(0xFF991B1B)]
                        : [const Color(0xFFFEE2E2), const Color(0xFFFECACA)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFFF87171),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fact_check_rounded,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Practice Hub & Revisão de Erros',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : Colors.red.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Itens errados em exercícios retornam automaticamente. Acerte duas vezes consecutivas para dominar e limpar do caderno!',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.red.shade100
                                  : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // KPI stats row
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Text(
                              '$unresolved',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Para Revisar',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Text(
                              '$resolved',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Dominados',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_mistakes.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 48,
                    horizontal: 24,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.celebration_rounded,
                        size: 64,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Caderno de Erros Vazio!',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Você dominou todas as questões ou ainda não errou nenhuma pergunta recente. Continue assim!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ..._mistakes.map((m) {
                  final consecutive = m['consecutiveCorrect'] as int? ?? 0;
                  final question = m['question'] as String? ?? '';
                  final wrongAnswer = m['userWrongAnswer'] as String? ?? '';
                  final correctAnswer = m['correctAnswer'] as String? ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Progresso: $consecutive/2 acertos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.volume_up_rounded,
                                  size: 20,
                                ),
                                tooltip: 'Ouvir pronúncia',
                                onPressed: () {
                                  AudioSpeechHelper.speak(
                                    correctAnswer.isNotEmpty
                                        ? correctAnswer
                                        : question,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Text(
                                  '🐢',
                                  style: TextStyle(fontSize: 16),
                                ),
                                tooltip: 'Modo Tartaruga (áudio lento)',
                                onPressed: () {
                                  AudioSpeechHelper.speak(
                                    correctAnswer.isNotEmpty
                                        ? correctAnswer
                                        : question,
                                    rate: 0.6,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            question,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Answers display
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.close_rounded,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Sua resposta: $wrongAnswer',
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF16A34A),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Resposta correta: $correctAnswer',
                                    style: TextStyle(
                                      color: Colors.green.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Actions
                          Row(
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.psychology_rounded,
                                  size: 18,
                                ),
                                label: const Text('Explicar com IA'),
                                onPressed: () => _showAiExplanationDialog(m),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text('Acertei agora!'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () =>
                                          _reviewMistake(m['id'] as int, true),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _AiExplanationDialog extends StatefulWidget {
  const _AiExplanationDialog({required this.mistake, required this.dio});

  final Map<String, dynamic> mistake;
  final Dio dio;

  @override
  State<_AiExplanationDialog> createState() => _AiExplanationDialogState();
}

class _AiExplanationDialogState extends State<_AiExplanationDialog> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _explanationData;

  @override
  void initState() {
    super.initState();
    _fetchAiExplanation();
  }

  Future<void> _fetchAiExplanation() async {
    try {
      final res = await widget.dio.post(
        '/api/ai/explain-mistake',
        data: {
          'question': widget.mistake['question'],
          'wrongAnswer': widget.mistake['userWrongAnswer'],
          'correctAnswer': widget.mistake['correctAnswer'],
          'language': 'Inglês',
        },
      );
      if (mounted) {
        setState(() {
          _explanationData = Map<String, dynamic>.from(res.data ?? {});
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Não foi possível carregar a explicação com IA no momento: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.auto_awesome_rounded, color: Color(0xFF7651C8)),
          SizedBox(width: 8),
          Text('Explicação Pedagógica IA'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _loading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Gerando análise pedagógica e mnemônica...'),
                ],
              )
            : _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.red))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _explanationData?['explanation'] ?? '',
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: const [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 18,
                          color: Colors.blueAccent,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Regra Gramatical:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_explanationData?['grammarRule'] ?? ''),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 18,
                          color: Colors.amber,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Dica Mnemônica:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_explanationData?['memoryTip'] ?? ''),
                    if (_explanationData?['similarExamples'] is List &&
                        (_explanationData!['similarExamples'] as List)
                            .isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Exemplos Semelhantes:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      ...((_explanationData!['similarExamples'] as List).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '• $e',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      )),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido!'),
        ),
      ],
    );
  }
}
