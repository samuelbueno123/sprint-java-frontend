import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import '../audio_speech_helper.dart';

class AiConversationView extends StatefulWidget {
  const AiConversationView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AiConversationView> createState() => _AiConversationViewState();
}

class _AiConversationViewState extends State<AiConversationView> {
  final Dio _dio = ApiClient().dio;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _scenarios = [];
  Map<String, dynamic>? _currentSession;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _mistakes = [];

  bool _loading = false;
  bool _sending = false;
  bool _listening = false;
  bool _showMistakesDrawer = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadScenarios() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/api/ai/conversations/scenarios');
      if (!mounted) return;
      setState(() {
        _scenarios = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar cenários.';
        _loading = false;
      });
    }
  }

  Future<void> _startSession(Map<String, dynamic> scenario) async {
    setState(() => _loading = true);
    try {
      final res = await _dio.post('/api/ai/conversations/start', data: {
        'scenarioCode': scenario['code'],
        'targetLanguage': 'Inglês',
        'cefrLevel': scenario['cefrLevel'],
      });

      final sessionData = Map<String, dynamic>.from(res.data as Map);
      setState(() {
        _currentSession = sessionData;
        _messages = ((sessionData['messages'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = 'Erro ao iniciar conversa com IA.';
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _currentSession == null || _sending) return;

    final sessionId = _currentSession!['id'];
    _msgCtrl.clear();

    setState(() {
      _sending = true;
      // Optimistic user bubble
      _messages.add({
        'sender': 'USER',
        'content': text,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    try {
      final res = await _dio.post(
        '/api/ai/conversations/$sessionId/messages',
        data: {'message': text},
      );

      final updatedSession = Map<String, dynamic>.from(res.data as Map);
      setState(() {
        _currentSession = updatedSession;
        _messages = ((updatedSession['messages'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao enviar mensagem. Tente novamente.')),
        );
      }
    }
  }

  Future<void> _loadMistakes() async {
    try {
      final res = await _dio.get('/api/ai/conversations/my-mistakes');
      setState(() {
        _mistakes = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _showMistakesDrawer = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar caderno de erros.')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_showMistakesDrawer) {
      return _buildMistakesView(colors);
    }

    if (_currentSession == null) {
      return _buildScenarioSelector(colors);
    }

    return _buildChatInterface(colors);
  }

  Widget _buildScenarioSelector(ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: widget.onBack),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Conversação Interativa com IA', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text(
                      'Pratique diálogos do cotidiano em tempo real com correções pedagógicas e estímulo ativo da fala.',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadMistakes,
                icon: const Icon(Icons.bookmark_border_rounded, size: 18),
                label: const Text('Caderno de Erros'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Escolha um cenário para iniciar:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.35,
                ),
                itemCount: _scenarios.length,
                itemBuilder: (context, index) {
                  final s = _scenarios[index];
                  return _buildScenarioCard(colors, s);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioCard(ColorScheme colors, Map<String, dynamic> s) {
    final title = s['title'] ?? '';
    final desc = s['description'] ?? '';
    final level = s['cefrLevel'] ?? 'A2';
    final role = s['personaRole'] ?? '';
    final category = s['category'] ?? 'Geral';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _startSession(s),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(level, style: TextStyle(color: colors.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  Text(category, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFF3579E8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Interlocutor: $role',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF3579E8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatInterface(ColorScheme colors) {
    final title = _currentSession?['scenarioTitle'] ?? 'Conversação';
    final role = _currentSession?['personaRole'] ?? 'Assistente IA';
    final turns = _currentSession?['totalTurns'] ?? 0;
    final corrections = _currentSession?['grammarCorrectionsCount'] ?? 0;

    return Column(
      children: [
        // Top session bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _currentSession = null),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF3579E8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Interlocutor: $role • $turns turnos • $corrections correções', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  if (_currentSession != null) {
                    await _dio.post('/api/ai/conversations/${_currentSession!['id']}/end');
                  }
                  setState(() => _currentSession = null);
                },
                child: const Text('Encerrar'),
              ),
            ],
          ),
        ),

        // Message list
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg['sender'] == 'USER';
              return _buildMessageBubble(colors, msg, isUser);
            },
          ),
        ),

        if (_sending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('$role está digitando...', style: TextStyle(fontStyle: FontStyle.italic, color: colors.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(_listening ? Icons.mic_rounded : Icons.mic_none_rounded, color: _listening ? Colors.red : null),
                tooltip: 'Falar por áudio (Speech to text)',
                onPressed: () async {
                  setState(() => _listening = true);
                  final text = await AudioSpeechHelper.recognizeSpeech(languageName: 'Inglês');
                  setState(() {
                    _listening = false;
                    if (text != null && text.isNotEmpty) {
                      _msgCtrl.text = text;
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Escreva sua resposta no idioma...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _sendMessage,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                child: const Icon(Icons.send_rounded, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ColorScheme colors, Map<String, dynamic> msg, bool isUser) {
    final content = msg['content'] ?? '';
    final hasIssues = msg['hasGrammarIssues'] == true;
    final correction = msg['grammarCorrection'];
    final explanation = msg['explanation'];
    final nativeAlt = msg['betterNativeAlternative'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.primaryContainer,
                  child: const Icon(Icons.smart_toy_rounded, size: 18, color: Color(0xFF3579E8)),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF3579E8) : colors.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    content,
                    style: TextStyle(
                      color: isUser ? Colors.white : colors.onSurface,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // AI Pedagogical Feedback Card for User speech
          if (isUser && hasIssues) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_fix_high_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text('Correção Pedagógica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber[900])),
                    ],
                  ),
                  if (correction != null) ...[
                    const SizedBox(height: 4),
                    Text('Correto: "$correction"', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                  if (explanation != null) ...[
                    const SizedBox(height: 4),
                    Text(explanation, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  ],
                  if (nativeAlt != null && nativeAlt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Como um nativo diria: "$nativeAlt"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.teal)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMistakesView(ColorScheme colors) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _showMistakesDrawer = false),
        ),
        title: const Text('Caderno de Erros & Anotações da IA'),
      ),
      body: _mistakes.isEmpty
          ? const Center(child: Text('Nenhum erro registrado ainda. Excelente trabalho!'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mistakes.length,
              itemBuilder: (context, index) {
                final m = _mistakes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Você disse: "${m['originalText'] ?? ''}"', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Forma correta: "${m['correctedText'] ?? ''}"', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(m['explanation'] ?? '', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
                        if (m['betterNativeAlternative'] != null) ...[
                          const SizedBox(height: 6),
                          Text('Alternativa idiomática: "${m['betterNativeAlternative']}"', style: const TextStyle(color: Colors.teal, fontStyle: FontStyle.italic, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
