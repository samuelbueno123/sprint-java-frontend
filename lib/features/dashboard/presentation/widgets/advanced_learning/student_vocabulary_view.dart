import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/network/api_client.dart';
import '../audio_speech_helper.dart';

class StudentVocabularyView extends StatefulWidget {
  const StudentVocabularyView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<StudentVocabularyView> createState() => _StudentVocabularyViewState();
}

class _StudentVocabularyViewState extends State<StudentVocabularyView> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _loadFuture;

  List<Map<String, dynamic>> _vocabulary = [];
  String _selectedLanguage = 'Todos';
  String _selectedMastery = 'TODOS';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _languages = [
    'Todos',
    'Inglês',
    'Espanhol',
    'Francês',
    'Alemão',
    'Italiano',
  ];

  @override
  void initState() {
    super.initState();
    _loadFuture = _fetchVocabulary();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchVocabulary() async {
    try {
      final queryParams = <String, dynamic>{};
      if (_selectedLanguage != 'Todos') {
        queryParams['language'] = _selectedLanguage;
      }
      if (_selectedMastery != 'TODOS') {
        queryParams['masteryLevel'] = _selectedMastery;
      }
      if (_searchQuery.trim().isNotEmpty) {
        queryParams['search'] = _searchQuery.trim();
      }

      final res = await _dio.get(
        '/api/students/me/vocabulary',
        queryParameters: queryParams,
      );
      if (mounted) {
        setState(() {
          _vocabulary = List<Map<String, dynamic>>.from(res.data ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar vocabulário: $e')),
        );
      }
    }
  }

  Future<void> _addWordDialog() async {
    final termCtrl = TextEditingController();
    final transCtrl = TextEditingController();
    final exampleCtrl = TextEditingController();
    String language = _selectedLanguage != 'Todos'
        ? _selectedLanguage
        : 'Inglês';
    String partOfSpeech = 'SUBSTANTIVO';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Adicionar Nova Palavra ao Cofre'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: language,
                  decoration: const InputDecoration(labelText: 'Idioma'),
                  items: _languages.where((l) => l != 'Todos').map((l) {
                    return DropdownMenuItem(value: l, child: Text(l));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => language = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: termCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Termo / Expressão',
                    hintText: 'Ex: resilient',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: transCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tradução / Significado',
                    hintText: 'Ex: resiliente, resistente',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: partOfSpeech,
                  decoration: const InputDecoration(
                    labelText: 'Classe Gramatical',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'SUBSTANTIVO',
                      child: Text('Substantivo'),
                    ),
                    DropdownMenuItem(value: 'VERBO', child: Text('Verbo')),
                    DropdownMenuItem(
                      value: 'ADJETIVO',
                      child: Text('Adjetivo'),
                    ),
                    DropdownMenuItem(
                      value: 'ADVERBIO',
                      child: Text('Advérbio'),
                    ),
                    DropdownMenuItem(
                      value: 'EXPRESSAO',
                      child: Text('Expressão Idiomática'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => partOfSpeech = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exampleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Frase de Exemplo (Opcional)',
                    hintText: 'Ex: She proved to be very resilient.',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (result == true &&
        termCtrl.text.trim().isNotEmpty &&
        transCtrl.text.trim().isNotEmpty) {
      try {
        await _dio.post(
          '/api/students/me/vocabulary',
          data: {
            'language': language,
            'term': termCtrl.text.trim(),
            'translation': transCtrl.text.trim(),
            'partOfSpeech': partOfSpeech,
            'exampleSentence': exampleCtrl.text.trim().isEmpty
                ? null
                : exampleCtrl.text.trim(),
            'masteryLevel': 'LEARNING',
          },
        );
        _fetchVocabulary();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Palavra salva no seu cofre pessoal!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao salvar palavra: $e')));
        }
      }
    }
  }

  Future<void> _updateMastery(int id, String level) async {
    try {
      await _dio.patch(
        '/api/students/me/vocabulary/$id/mastery',
        data: {'masteryLevel': level},
      );
      _fetchVocabulary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar nível: $e')));
      }
    }
  }

  Future<void> _deleteWord(int id) async {
    try {
      await _dio.delete('/api/students/me/vocabulary/$id');
      _fetchVocabulary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
      }
    }
  }

  Color _getMasteryColor(String? level) {
    switch (level?.toUpperCase()) {
      case 'MASTERED':
        return const Color(0xFF16A34A);
      case 'REVIEWING':
        return Colors.amber.shade800;
      default:
        return const Color(0xFF3579E8);
    }
  }

  String _getMasteryLabel(String? level) {
    switch (level?.toUpperCase()) {
      case 'MASTERED':
        return 'Dominado 🌟';
      case 'REVIEWING':
        return 'Revisando 🔄';
      default:
        return 'Aprendendo 📖';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Meu Vocabulário (Cofre Pessoal)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar Termo'),
        onPressed: _addWordDialog,
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar palavras ou traduções...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                              _fetchVocabulary();
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _fetchVocabulary();
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedLanguage,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Idioma',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _languages
                            .map(
                              (l) => DropdownMenuItem(value: l, child: Text(l)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedLanguage = val);
                            _fetchVocabulary();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedMastery,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Nível de Domínio',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'TODOS',
                            child: Text('Todos os níveis'),
                          ),
                          DropdownMenuItem(
                            value: 'LEARNING',
                            child: Text('Aprendendo'),
                          ),
                          DropdownMenuItem(
                            value: 'REVIEWING',
                            child: Text('Revisando'),
                          ),
                          DropdownMenuItem(
                            value: 'MASTERED',
                            child: Text('Dominado'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMastery = val);
                            _fetchVocabulary();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Words list
          Expanded(
            child: FutureBuilder(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_vocabulary.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma palavra encontrada',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Adicione palavras desconhecidas com exemplos e pronúncia para enriquecer seu repertório!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vocabulary.length,
                  itemBuilder: (context, index) {
                    final item = _vocabulary[index];
                    final term = item['term'] as String? ?? '';
                    final translation = item['translation'] as String? ?? '';
                    final language = item['language'] as String? ?? 'Inglês';
                    final mastery =
                        item['masteryLevel'] as String? ?? 'LEARNING';
                    final example = item['exampleSentence'] as String?;
                    final partOfSpeech =
                        item['partOfSpeech'] as String? ?? 'PALAVRA';

                    final masteryColor = _getMasteryColor(mastery);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
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
                                    color: masteryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _getMasteryLabel(mastery),
                                    style: TextStyle(
                                      color: masteryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    partOfSpeech,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const Spacer(),

                                // Audio controls
                                IconButton(
                                  icon: const Icon(
                                    Icons.volume_up_rounded,
                                    size: 20,
                                  ),
                                  tooltip: 'Pronúncia padrão (1.0x)',
                                  onPressed: () {
                                    AudioSpeechHelper.speak(
                                      term,
                                      languageName: language,
                                      rate: 1.0,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Text(
                                    '🐢',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  tooltip: 'Modo Tartaruga (áudio lento 0.6x)',
                                  onPressed: () {
                                    AudioSpeechHelper.speak(
                                      term,
                                      languageName: language,
                                      rate: 0.6,
                                    );
                                  },
                                ),

                                // Options menu
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    size: 20,
                                  ),
                                  onSelected: (val) {
                                    if (val == 'DELETE') {
                                      _deleteWord(item['id'] as int);
                                    } else {
                                      _updateMastery(item['id'] as int, val);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'LEARNING',
                                      child: Text('Mover para: Aprendendo'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'REVIEWING',
                                      child: Text('Mover para: Revisando'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'MASTERED',
                                      child: Text('Mover para: Dominado'),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'DELETE',
                                      child: Text(
                                        'Excluir palavra',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              term,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              translation,
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? Colors.blue.shade200
                                    : const Color(0xFF1D4ED8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (example != null && example.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '“$example”',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
