import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';

class SrsReviewView extends StatefulWidget {
  const SrsReviewView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<SrsReviewView> createState() => _SrsReviewViewState();
}

class _SrsReviewViewState extends State<SrsReviewView> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _loadFuture;

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _stats;
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _submitting = false;
  String? _error;
  int _sessionXp = 0;
  int _sessionReviewedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _error = null;
    });
    try {
      final responses = await Future.wait([
        _dio.get('/api/srs/session'),
        _dio.get('/api/srs/stats'),
      ]);

      if (!mounted) return;
      setState(() {
        _items = (responses[0].data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _stats = responses[1].data is Map ? Map<String, dynamic>.from(responses[1].data as Map) : null;
        _currentIndex = 0;
        _isFlipped = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar a sessão de revisão. Verifique sua conexão.';
      });
    }
  }

  Future<void> _submitReview(int rating) async {
    if (_items.isEmpty || _currentIndex >= _items.length || _submitting) return;

    final currentItem = _items[_currentIndex];
    final itemId = currentItem['id'];

    setState(() {
      _submitting = true;
    });

    try {
      final response = await _dio.post(
        '/api/srs/review/$itemId',
        data: {'rating': rating},
      );

      final updated = Map<String, dynamic>.from(response.data as Map);
      final xpGained = (updated['xpEarned'] as num?)?.toInt() ?? 5;

      setState(() {
        _sessionXp += xpGained;
        _sessionReviewedCount++;
        _isFlipped = false;
        _currentIndex++;
        _submitting = false;
      });

      if (_currentIndex >= _items.length) {
        // Refresh stats
        final statsRes = await _dio.get('/api/srs/stats');
        if (mounted) {
          setState(() {
            _stats = Map<String, dynamic>.from(statsRes.data as Map);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar revisão. Tente novamente.')),
        );
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showAddCardDialog() {
    final termCtrl = TextEditingController();
    final translationCtrl = TextEditingController();
    final exampleCtrl = TextEditingController();
    final exampleTranslationCtrl = TextEditingController();
    String category = 'geral';
    String cefrLevel = 'B1';
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_card_rounded, color: Color(0xFF3579E8)),
              SizedBox(width: 8),
              Text('Novo Flashcard'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: termCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Termo / Expressão *',
                    hintText: 'ex: overwhelmed',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: translationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tradução / Significado *',
                    hintText: 'ex: sobrecarregado(a)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exampleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Frase de Exemplo',
                    hintText: 'ex: She felt overwhelmed by the work.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exampleTranslationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tradução do Exemplo',
                    hintText: 'ex: Ela se sentiu sobrecarregada com o trabalho.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: cefrLevel,
                        decoration: const InputDecoration(labelText: 'Nível CEFR', border: OutlineInputBorder()),
                        items: ['A1', 'A2', 'B1', 'B2', 'C1'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                        onChanged: (v) => setDialogState(() => cefrLevel = v ?? 'B1'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                        items: ['geral', 'adjetivo', 'verbo', 'substantivo', 'phrasal verb', 'expressão'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setDialogState(() => category = v ?? 'geral'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving ? null : () async {
                if (termCtrl.text.trim().isEmpty || translationCtrl.text.trim().isEmpty) return;
                setDialogState(() => saving = true);
                try {
                  await _dio.post('/api/srs/items', data: {
                    'languageName': 'Inglês',
                    'term': termCtrl.text.trim(),
                    'translation': translationCtrl.text.trim(),
                    'exampleSentence': exampleCtrl.text.trim(),
                    'exampleTranslation': exampleTranslationCtrl.text.trim(),
                    'category': category,
                    'cefrLevel': cefrLevel,
                  });
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _loadData();
                } catch (e) {
                  setDialogState(() => saving = false);
                }
              },
              child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Salvar'),
            ),
          ],
        ),
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
                Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: colors.error)),
                const SizedBox(height: 16),
                FilledButton.tonal(onPressed: _loadData, child: const Text('Tentar novamente')),
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
                          'Revisão Espaçada Inteligente (SRS)',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Otimização baseada no algoritmo SuperMemo SM-2 com intervalos cientificamente calculados.',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showAddCardDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Novo Card'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats Row
              if (_stats != null) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStatPill(Icons.pending_actions_rounded, '${_stats!['dueTodayCount'] ?? 0}', 'Para hoje', colors.primary),
                    _buildStatPill(Icons.schedule_rounded, '${_stats!['upcomingCount'] ?? 0}', 'Próximos dias', Colors.purple),
                    _buildStatPill(Icons.verified_rounded, '${_stats!['masteredCount'] ?? 0}', 'Dominados', Colors.green),
                    _buildStatPill(Icons.trending_up_rounded, '${_stats!['retentionRate'] ?? 0}%', 'Taxa de Retenção', Colors.teal),
                    if (_sessionXp > 0)
                      _buildStatPill(Icons.bolt_rounded, '+$_sessionXp XP', 'Ganhos na sessão', Colors.amber[800]!),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Card Session
              if (_items.isEmpty || _currentIndex >= _items.length) ...[
                _buildSessionCompleted(colors),
              ] else ...[
                _buildActiveCard(colors, _items[_currentIndex]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatPill(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(ColorScheme colors, Map<String, dynamic> item) {
    final term = item['term'] ?? '';
    final translation = item['translation'] ?? '';
    final example = item['exampleSentence'] ?? '';
    final exampleTranslation = item['exampleTranslation'] ?? '';
    final cefr = item['cefrLevel'] ?? 'A2';
    final repetition = item['repetitionNumber'] ?? 0;
    final interval = item['intervalDays'] ?? 1;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _items.length,
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Card ${_currentIndex + 1} de ${_items.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Repetição #$repetition • Intervalo: $interval d', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            // Flip Card
            GestureDetector(
              onTap: () => setState(() => _isFlipped = !_isFlipped),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _isFlipped ? colors.primary : colors.outlineVariant, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(cefr, style: TextStyle(color: colors.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        Text(
                          _isFlipped ? 'Toque para ocultar' : 'Toque para ver a resposta',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      term,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                    if (example.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '"$example"',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontStyle: FontStyle.italic, color: colors.onSurfaceVariant, fontSize: 16),
                      ),
                    ],
                    if (_isFlipped) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        translation,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: colors.primary),
                      ),
                      if (exampleTranslation.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '"$exampleTranslation"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // SM-2 Quality Buttons
            if (_isFlipped) ...[
              const Text('Como foi sua lembrança deste termo?', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQualityButton(
                      label: 'Errei',
                      subtext: '< 1 dia',
                      color: Colors.red,
                      onTap: () => _submitReview(1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQualityButton(
                      label: 'Difícil',
                      subtext: '~ 1-2 dias',
                      color: Colors.orange,
                      onTap: () => _submitReview(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQualityButton(
                      label: 'Bom',
                      subtext: '~ 4-6 dias',
                      color: Colors.blue,
                      onTap: () => _submitReview(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQualityButton(
                      label: 'Fácil',
                      subtext: '+ 10 dias',
                      color: Colors.green,
                      onTap: () => _submitReview(4),
                    ),
                  ),
                ],
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: () => setState(() => _isFlipped = true),
                icon: const Icon(Icons.flip_rounded),
                label: const Text('Mostrar Resposta'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQualityButton({required String label, required String subtext, required Color color, required VoidCallback onTap}) {
    return OutlinedButton(
      onPressed: _submitting ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(subtext, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildSessionCompleted(ColorScheme colors) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              const Icon(Icons.celebration_rounded, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              const Text('Parabéns! Revisão Concluída', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Você revisou $_sessionReviewedCount cards hoje e ganhou +$_sessionXp XP! Seu cérebro consolidou os caminhos neurais da memória.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Atualizar Sessão'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
