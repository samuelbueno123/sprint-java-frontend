import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/constants/supported_languages.dart';
import 'package:frontend/core/network/api_client.dart';

class _CommunitySubmissionDialog extends StatefulWidget {
  const _CommunitySubmissionDialog({required this.onSubmit});

  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  @override
  State<_CommunitySubmissionDialog> createState() =>
      _CommunitySubmissionDialogState();
}

class _CommunitySubmissionDialogState
    extends State<_CommunitySubmissionDialog> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();
  String _language = 'Inglês';
  String _targetLevel = 'A2';
  bool _saving = false;
  String? _validationError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(
        () =>
            _validationError = 'Preencha o título e o texto antes de publicar.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _validationError = null;
    });
    try {
      await widget.onSubmit(<String, dynamic>{
        'language': _language,
        'promptTitle': title,
        'content': content,
        'targetLevel': _targetLevel,
        'isPublic': true,
      });
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao publicar exercício: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Enviar Exercício para Revisão Comunitária'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(
                labelText: 'Idioma',
                border: OutlineInputBorder(),
              ),
              items: kSupportedLanguages
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _language = v ?? 'Inglês'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _targetLevel,
              decoration: const InputDecoration(
                labelText: 'Nível Pretendido',
                border: OutlineInputBorder(),
              ),
              items: [
                'A1',
                'A2',
                'B1',
                'B2',
                'C1',
              ].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) => setState(() => _targetLevel = v ?? 'A2'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Título / Tema do Texto *',
                hintText: 'ex: O que eu fiz no final de semana',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Seu Texto no Idioma Estudado *',
                hintText:
                    'Escreva sua resposta para outros estudantes revisarem...',
                border: OutlineInputBorder(),
              ),
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
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Publicar'),
        ),
      ],
    );
  }
}

class _CommunityReviewDialog extends StatefulWidget {
  const _CommunityReviewDialog({
    required this.submission,
    required this.onSubmit,
  });

  final Map<String, dynamic> submission;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  @override
  State<_CommunityReviewDialog> createState() => _CommunityReviewDialogState();
}

class _CommunityReviewDialogState extends State<_CommunityReviewDialog> {
  final TextEditingController _feedbackCtrl = TextEditingController();
  late final TextEditingController _correctionCtrl;
  final TextEditingController _nativeTipsCtrl = TextEditingController();
  int _rating = 5;
  bool _saving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _correctionCtrl = TextEditingController(
      text: widget.submission['content']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    _correctionCtrl.dispose();
    _nativeTipsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final feedback = _feedbackCtrl.text.trim();
    final correction = _correctionCtrl.text.trim();
    if (feedback.isEmpty || correction.isEmpty) {
      setState(
        () => _validationError =
            'Preencha o texto corrigido e o feedback antes de enviar.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _validationError = null;
    });
    try {
      await widget.onSubmit(<String, dynamic>{
        'submissionId': widget.submission['id'],
        'overallFeedback': feedback,
        'correctedContent': correction,
        'nativeSpeakerTips': _nativeTipsCtrl.text.trim(),
        'rating': _rating,
      });
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não tem permissão para avaliar este exercício.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Avaliar Texto de ${widget.submission['authorName'] ?? 'Estudante'}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tema: ${widget.submission['promptTitle'] ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${widget.submission['content'] ?? ''}"',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _correctionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Texto Corrigido *',
                helperText: 'Reescreva ajustando gramática e ortografia',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Feedback e Comentários *',
                hintText: 'Explique com gentileza o que pode melhorar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nativeTipsCtrl,
              decoration: const InputDecoration(
                labelText: 'Como um nativo diria (opcional)',
                hintText: 'Sugira expressões idiomáticas mais naturais',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Nota: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...List.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    icon: Icon(
                      star <= _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber,
                    ),
                    onPressed: () => setState(() => _rating = star),
                  );
                }),
              ],
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 6),
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
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Enviar Avaliação (+25 XP)'),
        ),
      ],
    );
  }
}

class CommunityPeerReviewView extends StatefulWidget {
  const CommunityPeerReviewView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<CommunityPeerReviewView> createState() =>
      _CommunityPeerReviewViewState();
}

class _CommunityPeerReviewViewState extends State<CommunityPeerReviewView>
    with SingleTickerProviderStateMixin {
  final Dio _dio = ApiClient().dio;
  late TabController _tabController;

  List<Map<String, dynamic>> _feedSubmissions = [];
  List<Map<String, dynamic>> _mySubmissions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        _dio.get('/api/community/feed'),
        _dio.get('/api/community/my-submissions'),
      ]);

      if (!mounted) return;
      setState(() {
        _feedSubmissions = (res[0].data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _mySubmissions = (res[1].data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar comunidade: $e')),
      );
    }
  }

  Future<void> _showNewSubmissionDialog() async {
    final published = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CommunitySubmissionDialog(
        onSubmit: (payload) =>
            _dio.post('/api/community/submissions', data: payload),
      ),
    );
    if (!mounted || published != true) return;
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercício enviado com sucesso para a comunidade!'),
        ),
      );
    }
  }

  Future<void> _showReviewDialog(Map<String, dynamic> submission) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CommunityReviewDialog(
        submission: submission,
        onSubmit: (payload) =>
            _dio.post('/api/community/reviews', data: payload),
      ),
    );
    if (!mounted || submitted != true) return;
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação enviada! Você ganhou +25 XP.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
                      'Correção Colaborativa & Comunidade',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Pratique escrita, envie para falantes fluentes avaliarem e ganhe XP corrigindo outros alunos.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _showNewSubmissionDialog,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Novo Exercício'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tabs
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Feed de Exercícios (${_feedSubmissions.length})'),
              Tab(text: 'Minhas Submissões (${_mySubmissions.length})'),
            ],
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else
            SizedBox(
              height: 600,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFeedTab(colors),
                  _buildMySubmissionsTab(colors),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedTab(ColorScheme colors) {
    if (_feedSubmissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.done_all_rounded, size: 48, color: Colors.green),
            const SizedBox(height: 12),
            const Text(
              'Nenhum exercício pendente no momento.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Volte mais tarde ou publique seu próprio texto!',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _feedSubmissions.length,
      itemBuilder: (context, index) {
        final sub = _feedSubmissions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sub['authorName'] ?? 'Estudante',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${sub['language']} • ${sub['targetLevel']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  sub['promptTitle'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '"${sub['content'] ?? ''}"',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _showReviewDialog(sub),
                      icon: const Icon(Icons.rate_review_rounded, size: 16),
                      label: const Text('Corrigir Texto (+25 XP)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMySubmissionsTab(ColorScheme colors) {
    if (_mySubmissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.post_add_rounded,
              size: 48,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 12),
            const Text(
              'Você ainda não enviou nenhum exercício.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _showNewSubmissionDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Publicar Primeiro Exercício'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _mySubmissions.length,
      itemBuilder: (context, index) {
        final sub = _mySubmissions[index];
        final reviews = ((sub['reviews'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sub['promptTitle'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${reviews.length} avaliações',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Seu texto original: "${sub['content'] ?? ''}"',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),

                if (reviews.isNotEmpty) ...[
                  const Divider(),
                  const Text(
                    'Correções Recebidas:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...reviews.map(
                    (r) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${r['reviewerName']} (${r['reviewerFluencyLevel']})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Row(
                                children: List.generate(
                                  (r['rating'] as num?)?.toInt() ?? 5,
                                  (_) => const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Texto Corrigido: "${r['correctedContent']}"',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r['overallFeedback'] ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (r['nativeSpeakerTips'] != null &&
                              (r['nativeSpeakerTips'] as String)
                                  .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Dica de Nativo: "${r['nativeSpeakerTips']}"',
                              style: const TextStyle(
                                color: Colors.teal,
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
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
  }
}
