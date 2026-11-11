import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import '../audio_speech_helper.dart';

class PronunciationPracticeView extends StatefulWidget {
  const PronunciationPracticeView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<PronunciationPracticeView> createState() =>
      _PronunciationPracticeViewState();
}

class _PronunciationPracticeViewState extends State<PronunciationPracticeView> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _loadFuture;

  List<Map<String, dynamic>> _challenges = [];
  Map<String, dynamic>? _selectedChallenge;
  Map<String, dynamic>? _evaluationResult;
  bool _evaluating = false;
  bool _isListening = false;
  String _spokenText = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() => _error = null);
    try {
      final res = await _dio.get('/api/pronunciation/challenges');
      if (!mounted) return;
      setState(() {
        _challenges = (res.data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (_challenges.isNotEmpty) {
          _selectedChallenge = _challenges.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Erro ao carregar desafios de pronúncia.');
    }
  }

  Future<void> _startRecording() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      _spokenText = '';
      _evaluationResult = null;
    });

    try {
      final recognized = await AudioSpeechHelper.recognizeSpeech(
        languageName: 'Inglês',
      );
      setState(() {
        _isListening = false;
        _spokenText = recognized ?? '';
      });

      if (recognized != null &&
          recognized.trim().isNotEmpty &&
          _selectedChallenge != null) {
        _evaluateSpeech(recognized.trim());
      }
    } catch (e) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _evaluateSpeech(String spoken) async {
    if (_selectedChallenge == null || _evaluating) return;

    setState(() => _evaluating = true);

    try {
      final res = await _dio.post(
        '/api/pronunciation/evaluate',
        data: {'challengeId': _selectedChallenge!['id'], 'spokenText': spoken},
      );

      setState(() {
        _evaluationResult = Map<String, dynamic>.from(res.data as Map);
        _evaluating = false;
      });
    } catch (e) {
      setState(() => _evaluating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao avaliar pronúncia. Tente novamente.'),
          ),
        );
      }
    }
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
                Icon(Icons.mic_off_rounded, size: 48, color: colors.error),
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: colors.error)),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _loadChallenges,
                  child: const Text('Tentar novamente'),
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
                          'Prática Oral & Avaliação de Pronúncia',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Reconhecimento de fala com análise fonética detalhada palavra por palavra e dicas de articulação.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Horizontal challenge selector
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _challenges.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final c = _challenges[index];
                    final isSelected = _selectedChallenge?['id'] == c['id'];
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text('${c['category']} (${c['cefrLevel']})'),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedChallenge = c;
                            _evaluationResult = null;
                            _spokenText = '';
                          });
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              if (_selectedChallenge != null)
                _buildChallengeCard(colors, _selectedChallenge!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChallengeCard(ColorScheme colors, Map<String, dynamic> c) {
    final phrase = c['phraseText'] ?? '';
    final phonetic = c['phoneticGuide'] ?? '';
    final translation = c['translation'] ?? '';
    final tips = c['phoneticTips'] ?? '';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          children: [
            // Target Phrase Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          c['cefrLevel'] ?? 'A1',
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.volume_up_rounded,
                          color: Color(0xFF3579E8),
                        ),
                        tooltip: 'Ouvir pronúncia nativa (TTS)',
                        onPressed: () => AudioSpeechHelper.speak(
                          phrase,
                          languageName: 'Inglês',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    phrase,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  if (phonetic.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      phonetic,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: colors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    translation,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                  if (tips.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tips,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
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
            const SizedBox(height: 24),

            // Microphone action
            GestureDetector(
              onTap: _startRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.red : const Color(0xFF3579E8),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_isListening ? Colors.red : const Color(0xFF3579E8))
                              .withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: _isListening ? 6 : 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isListening
                  ? 'Ouvindo... Fale a frase agora'
                  : 'Toque no microfone para falar',
              style: TextStyle(
                color: _isListening ? Colors.red : colors.onSurfaceVariant,
                fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (_spokenText.isNotEmpty && !_isListening) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Text(
                  'Áudio capturado: "$_spokenText"',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Evaluation Results
            if (_evaluating)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Analisando acurácia fonética...'),
                  ],
                ),
              ),

            if (_evaluationResult != null)
              _buildResultSection(colors, _evaluationResult!),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection(ColorScheme colors, Map<String, dynamic> result) {
    final finalScore = (result['finalScore'] as num?)?.toDouble() ?? 0.0;
    final accuracy = (result['accuracyScore'] as num?)?.toDouble() ?? 0.0;
    final completeness =
        (result['completenessScore'] as num?)?.toDouble() ?? 0.0;
    final xp = (result['xpEarned'] as num?)?.toInt() ?? 0;
    final summary = result['feedbackSummary'] ?? '';
    final words = ((result['wordBreakdown'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    Color scoreColor = finalScore >= 80
        ? Colors.green
        : (finalScore >= 55 ? Colors.orange : Colors.red);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '${finalScore.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pontuação Geral',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        'Precisão: ${accuracy.toStringAsFixed(0)}% • Completude: ${completeness.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (xp > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+$xp XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(summary, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 20),

          const Text(
            'Análise palavra por palavra:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: words.map((w) {
              final status = w['status'] ?? 'MATCHED';
              final expected = w['expectedWord'] ?? '';
              final spoken = w['spokenWord'] ?? '';

              Color chipColor;
              switch (status) {
                case 'PERFECT':
                  chipColor = Colors.green;
                  break;
                case 'ACCEPTABLE':
                  chipColor = Colors.lightGreen;
                  break;
                case 'MISPRONOUNCED':
                  chipColor = Colors.orange;
                  break;
                case 'OMITTED':
                  chipColor = Colors.red;
                  break;
                default:
                  chipColor = Colors.blueGrey;
              }

              return Tooltip(
                message: '${w['phoneticTip'] ?? ''} (Falado: "$spoken")',
                child: Chip(
                  backgroundColor: chipColor.withValues(alpha: 0.15),
                  side: BorderSide(color: chipColor.withValues(alpha: 0.5)),
                  label: Text(
                    expected,
                    style: TextStyle(
                      color: chipColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
