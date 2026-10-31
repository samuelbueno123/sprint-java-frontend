import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/teacher_class_assignment.dart';
import '../../domain/entities/teacher_profile.dart';
import 'responsive_layout.dart';
import 'teacher_exercise_preview_screen.dart';

class TeacherCreateExerciseScreen extends StatefulWidget {
  const TeacherCreateExerciseScreen({
    super.key,
    required this.data,
    required this.proficiencyLevels,
    required this.exercises,
    this.dataLoadError,
    required this.onBack,
    required this.onSaved,
  });

  final DashboardData data;
  final List<String> proficiencyLevels;
  final List<Map<String, dynamic>> exercises;
  final String? dataLoadError;
  final VoidCallback onBack;
  final Future<void> Function() onSaved;

  @override
  State<TeacherCreateExerciseScreen> createState() =>
      _TeacherCreateExerciseScreenState();
}

class _TeacherCreateExerciseScreenState
    extends State<TeacherCreateExerciseScreen> {
  static const _categories = [
    'Gramática',
    'Vocabulário',
    'Conversação',
    'Leitura',
    'Escrita',
    'Pronúncia',
  ];
  static const _questionStyles = [
    'Múltipla Escolha',
    'Discursiva',
    'Completar',
    'Tradução',
    'Correspondência',
    'Verdadeiro ou Falso',
    'Áudio',
  ];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _theme = TextEditingController();
  final _description = TextEditingController();
  final _content = TextEditingController();
  final _mediaUrl = TextEditingController();
  final _aiInstructions = TextEditingController();
  final List<_ComposerQuestion> _questions = [_ComposerQuestion()];

  final Dio _dio = ApiClient().dio;
  bool _contentOnly = false;
  bool _saving = false;
  bool _generatingAi = false;
  int _aiQuestionCount = 3;
  String? _aiStatusMessage;
  bool _aiStatusIsError = false;
  String _category = _categories.first;
  int? _classId;
  String? _language;
  String? _level;
  DateTime? _dueDate;

  TeacherProfile? get _teacher => widget.data.teacherProfile;
  List<TeacherClassAssignment> get _activeAssignments => widget
      .data
      .teacherAssignments
      .where((item) => item.isActive && item.schoolClassId != null)
      .toList();
  List<String> get _languages => _teacher?.taughtLanguages ?? const [];

  List<String> get _effectiveLevels {
    if (widget.proficiencyLevels.isNotEmpty) {
      return widget.proficiencyLevels;
    }
    return const ['Fácil', 'Médio', 'Difícil'];
  }

  @override
  void initState() {
    super.initState();
    final assignments = _activeAssignments;
    if (assignments.isNotEmpty) _classId = assignments.first.schoolClassId;
    if (_languages.isNotEmpty) _language = _languages.first;
    final levels = _effectiveLevels;
    if (levels.isNotEmpty) {
      _level = levels.contains(_level) ? _level : levels.first;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _theme.dispose();
    _description.dispose();
    _content.dispose();
    _mediaUrl.dispose();
    _aiInstructions.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  bool _usesOptions(String style) =>
      style == 'Múltipla Escolha' ||
      style == 'Correspondência' ||
      style == 'Verdadeiro ou Falso';

  Future<void> _pickDueDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 3),
    );
    if (selected != null && mounted) setState(() => _dueDate = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_activeAssignments.isEmpty ||
        _classId == null ||
        _language == null ||
        _level == null) {
      _showMessage(
        'Vincule uma turma ativa, um idioma e um nível ao perfil docente antes de publicar.',
      );
      return;
    }
    if (!_contentOnly) {
      for (var index = 0; index < _questions.length; index++) {
        final question = _questions[index];
        if (_usesOptions(question.style)) {
          final options = question.options
              .map((controller) => controller.text.trim())
              .where((value) => value.isNotEmpty)
              .toSet();
          if (options.length < 2) {
            _showMessage(
              'A questão ${index + 1} precisa de ao menos duas opções.',
            );
            return;
          }
          if (question.correctAnswer == null ||
              !options.contains(question.correctAnswer)) {
            _showMessage('Selecione o gabarito da questão ${index + 1}.');
            return;
          }
        } else if (question.expectedAnswer.text.trim().isEmpty) {
          _showMessage('Informe a resposta esperada da questão ${index + 1}.');
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      await _dio.post(
        '/api/exercises',
        data: {
          'title': _title.text.trim(),
          'category': _category,
          'theme': _theme.text.trim(),
          'languageName': _language,
          'proficiencyLevel': _level,
          'description': _description.text.trim(),
          'contentBody': _contentOnly ? _content.text.trim() : null,
          'mediaUrl': _mediaUrl.text.trim().isEmpty
              ? null
              : _mediaUrl.text.trim(),
          'dueDate': _dueDate == null
              ? null
              : '${_dueDate!.year.toString().padLeft(4, '0')}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
          'schoolClassId': _classId,
          'questions': _contentOnly
              ? <Map<String, dynamic>>[]
              : _questions.map(_questionToJson).toList(),
        },
      );
      if (!mounted) return;
      _showMessage(
        _contentOnly
            ? 'Conteúdo publicado para a turma.'
            : 'Atividade publicada para a turma.',
      );
      await widget.onSaved();
      if (!mounted) return;
      _resetForm();
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _questionToJson(_ComposerQuestion question) {
    final useOptions = _usesOptions(question.style);
    final options = question.options
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return {
      'style': question.style,
      'question': question.prompt.text.trim(),
      'options': useOptions ? options : <String>[],
      'correctAnswer': useOptions ? question.correctAnswer : null,
      'expectedAnswer': useOptions ? null : question.expectedAnswer.text.trim(),
    };
  }

  void _resetForm() {
    _title.clear();
    _theme.clear();
    _description.clear();
    _content.clear();
    _mediaUrl.clear();
    for (final question in _questions) {
      question.dispose();
    }
    setState(() {
      _questions
        ..clear()
        ..add(_ComposerQuestion());
      _contentOnly = false;
      _category = _categories.first;
      _dueDate = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
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
    return 'Não foi possível publicar. Revise os dados e tente novamente.';
  }

  Future<void> _preview() async {
    final previewQuestions = _questions.map((q) {
      return {
        'prompt': q.prompt.text.trim(),
        'style': q.style,
        'options': q.options
            .map((o) => o.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        'expectedAnswer': q.expectedAnswer.text.trim().isNotEmpty
            ? q.expectedAnswer.text.trim()
            : (q.correctAnswer ?? ''),
        'explanation': '',
      };
    }).toList();

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherExercisePreviewScreen(
          title: _title.text.trim().isEmpty
              ? 'Nova Atividade'
              : _title.text.trim(),
          category: _category,
          theme: _theme.text.trim().isEmpty ? 'Geral' : _theme.text.trim(),
          level: _level,
          questions: previewQuestions,
          contentBody: _contentOnly ? _content.text.trim() : null,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final teacher = _teacher;
    final assignments = _activeAssignments;
    return ListView(
      padding: responsivePagePadding(context),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, teacher, colors),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _contentTypeSelector(context),
                      const SizedBox(height: 16),
                      _informationCard(context, assignments, teacher),
                      if (_contentOnly) ...[
                        const SizedBox(height: 16),
                        _theoryCard(context),
                      ] else ...[
                        const SizedBox(height: 16),
                        _aiCard(context),
                        const SizedBox(height: 16),
                        _questionsCard(context),
                      ],
                      const SizedBox(height: 16),
                      _formActions(context),
                      const SizedBox(height: 24),
                      _publishedExercises(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    TeacherProfile? teacher,
    ColorScheme colors,
  ) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF7651C8), colors.primary],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7651C8).withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    padding: responsiveBannerPadding(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: widget.onBack,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Voltar ao painel'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Criar Exercício',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          teacher == null
              ? 'Crie atividades e conteúdos para suas turmas.'
              : 'Crie conteúdos para ${teacher.name} publicar às turmas.',
          style: TextStyle(color: Colors.white.withValues(alpha: .86)),
        ),
      ],
    ),
  );

  Widget _contentTypeSelector(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        final width = wide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _ContentTypeCard(
                selected: !_contentOnly,
                icon: Icons.menu_book_rounded,
                title: 'Atividade',
                subtitle: 'Contém perguntas e respostas',
                onTap: () => setState(() => _contentOnly = false),
              ),
            ),
            SizedBox(
              width: width,
              child: _ContentTypeCard(
                selected: _contentOnly,
                icon: Icons.description_outlined,
                title: 'Conteúdo teórico',
                subtitle: 'Texto ou mídia, sem questões',
                onTap: () => setState(() => _contentOnly = true),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _informationCard(
    BuildContext context,
    List<TeacherClassAssignment> assignments,
    TeacherProfile? teacher,
  ) {
    final colors = Theme.of(context).colorScheme;
    return _ComposerCard(
      title: 'Informações do Exercício',
      icon: Icons.assignment_outlined,
      child: Column(
        children: [
          _textField(
            controller: _title,
            label: 'Título do exercício',
            hint: 'Digite um título',
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Informe o título'
                : null,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final width = wide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Pacote (categoria)',
                      ),
                      items: _categories
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _textField(
                      controller: _theme,
                      label: 'Tema / Subtópico',
                      hint: 'Digite o tema',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<int>(
                      initialValue:
                          assignments.any(
                            (item) => item.schoolClassId == _classId,
                          )
                          ? _classId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Turma'),
                      hint: Text(
                        assignments.isEmpty
                            ? 'Nenhuma turma ativa'
                            : 'Selecione a turma',
                      ),
                      items: assignments
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.schoolClassId,
                              child: Text(
                                item.schoolClassName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _classId = value),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String>(
                      initialValue: _languages.contains(_language)
                          ? _language
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Idioma'),
                      hint: const Text('Selecione um idioma'),
                      items: _languages
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _language = value),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String>(
                      initialValue: _effectiveLevels.contains(_level)
                          ? _level
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Nível de dificuldade',
                        prefixIcon: Icon(Icons.signal_cellular_alt_rounded),
                      ),
                      hint: const Text('Selecione a dificuldade'),
                      items: _effectiveLevels
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: value == 'Fácil'
                                        ? const Color(0xFF2EB872)
                                        : value == 'Médio'
                                            ? const Color(0xFFE5902D)
                                            : value == 'Difícil'
                                                ? const Color(0xFFE53935)
                                                : const Color(0xFF5869D8),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(value),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _level = value),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        _dueDate == null
                            ? 'Prazo de entrega (opcional)'
                            : 'Prazo: ${_dateLabel(_dueDate!)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        alignment: Alignment.centerLeft,
                        foregroundColor: colors.onSurface,
                        side: BorderSide(color: colors.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _textField(
            controller: _description,
            label: 'Descrição (opcional)',
            hint: 'Adicione instruções ou contexto para os alunos.',
            maxLines: 3,
          ),
          if (assignments.isEmpty ||
              _languages.isEmpty ||
              widget.proficiencyLevels.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Para publicar, seu perfil precisa ter uma turma ativa, idioma lecionado e nível disponíveis.',
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _theoryCard(BuildContext context) => _ComposerCard(
    title: 'Conteúdo Teórico',
    icon: Icons.description_outlined,
    child: Column(
      children: [
        _textField(
          controller: _content,
          label: 'Corpo do conteúdo',
          hint: 'Escreva explicações, conceitos, exemplos ou regras.',
          maxLines: 9,
          validator: (value) {
            if (_contentOnly &&
                (value == null || value.trim().isEmpty) &&
                _mediaUrl.text.trim().isEmpty) {
              return 'Informe o texto teórico ou um link de mídia';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _textField(
          controller: _mediaUrl,
          label: 'Link de vídeo / áudio (opcional)',
          hint: 'Cole o link do material',
          keyboardType: TextInputType.url,
          validator: (value) {
            final text = value?.trim() ?? '';
            final uri = Uri.tryParse(text);
            if (text.isNotEmpty &&
                (uri == null ||
                    !uri.isAbsolute ||
                    !{'http', 'https'}.contains(uri.scheme))) {
              return 'Informe um link válido';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Conteúdo teórico não recebe respostas nem registra conclusão.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );

  String _normalizeGeneratedStyle(String? rawStyle) {
    final lower = (rawStyle ?? '').trim().toLowerCase();
    if (lower.contains('verdadeiro') || lower.contains('falso')) {
      return 'Verdadeiro ou Falso';
    }
    if (lower.contains('aberta') || lower.contains('discursiva')) {
      return 'Discursiva';
    }
    if (lower.contains('áudio') || lower.contains('audio')) {
      return 'Áudio';
    }
    if (lower.contains('completar') || lower.contains('lacuna')) {
      return 'Completar';
    }
    if (lower.contains('tradu')) {
      return 'Tradução';
    }
    return 'Múltipla Escolha';
  }

  Future<void> _generateWithAi() async {
    final themeText = _theme.text.trim();
    final instructionsText = _aiInstructions.text.trim();
    if (themeText.isEmpty && instructionsText.isEmpty) {
      setState(() {
        _aiStatusIsError = true;
        _aiStatusMessage =
            'Informe o Tema / Subtópico acima ou descreva as instruções para gerar as questões com IA.';
      });
      return;
    }

    setState(() {
      _generatingAi = true;
      _aiStatusMessage = null;
      _aiStatusIsError = false;
    });

    try {
      final response = await _dio.post<List<dynamic>>(
        '/api/exercises/generate-ai',
        data: {
          'languageName': _language ?? 'Inglês',
          'proficiencyLevel': _level ?? 'Fácil',
          'category': _category,
          'theme': themeText.isNotEmpty ? themeText : instructionsText,
          'questionCount': _aiQuestionCount,
          'questionStyles': _questionStyles,
          'additionalInstructions': instructionsText,
        },
      );
      final items = (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (items.isEmpty) {
        setState(() {
          _aiStatusIsError = true;
          _aiStatusMessage = 'O provedor de IA não retornou questões válidas.';
        });
        return;
      }

      final generated = <_ComposerQuestion>[];
      for (final item in items) {
        final q = _ComposerQuestion();
        q.style = _normalizeGeneratedStyle(item['style']?.toString());
        q.prompt.text = (item['question'] ?? '').toString().trim();
        final rawOpts = (item['options'] as List? ?? const [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (_usesOptions(q.style)) {
          final effectiveOpts = rawOpts.isNotEmpty
              ? rawOpts
              : (q.style == 'Verdadeiro ou Falso'
                    ? ['Verdadeiro', 'Falso']
                    : <String>[]);
          for (
            var i = 0;
            i < q.options.length && i < effectiveOpts.length;
            i++
          ) {
            q.options[i].text = effectiveOpts[i];
          }
          final correct = (item['correctAnswer'] ?? item['expectedAnswer'])
              ?.toString()
              .trim();
          if (correct != null && effectiveOpts.contains(correct)) {
            q.correctAnswer = correct;
          } else if (effectiveOpts.isNotEmpty) {
            q.correctAnswer = effectiveOpts.first;
          }
        } else {
          q.expectedAnswer.text =
              (item['expectedAnswer'] ?? item['correctAnswer'] ?? '')
                  .toString()
                  .trim();
        }
        generated.add(q);
      }

      for (final old in _questions) {
        old.dispose();
      }
      setState(() {
        _questions
          ..clear()
          ..addAll(generated);
        _aiStatusIsError = false;
        _aiStatusMessage =
            '${generated.length} questões geradas! Revise e edite livremente abaixo antes de publicar.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _aiStatusIsError = true;
        _aiStatusMessage = _errorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _generatingAi = false);
    }
  }

  Widget _aiCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _ComposerCard(
      title: 'Gerar com Inteligência Artificial',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Descreva o foco pedagógico das questões. As sugestões geradas serão preenchidas no editor abaixo para sua revisão antes de publicar.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: wide
                        ? constraints.maxWidth - 190
                        : constraints.maxWidth,
                    child: _textField(
                      controller: _aiInstructions,
                      label: 'Instruções para a IA (tema, vocabulário, foco)',
                      hint:
                          'Ex: Crie situações práticas de restaurante usando Simple Present',
                    ),
                  ),
                  SizedBox(
                    width: wide ? 178 : constraints.maxWidth,
                    child: DropdownButtonFormField<int>(
                      initialValue: _aiQuestionCount,
                      decoration: const InputDecoration(
                        labelText: 'Nº de questões',
                      ),
                      items: const [2, 3, 4, 5, 6]
                          .map(
                            (count) => DropdownMenuItem(
                              value: count,
                              child: Text('$count questões'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _aiQuestionCount = val);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _generatingAi ? null : _generateWithAi,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7651C8),
                foregroundColor: Colors.white,
              ),
              icon: _generatingAi
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                _generatingAi
                    ? 'Gerando sugestões...'
                    : 'Gerar questões para revisão',
              ),
            ),
          ),
          if (_aiStatusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _aiStatusIsError
                    ? colors.errorContainer
                    : colors.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _aiStatusIsError
                        ? Icons.info_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: _aiStatusIsError
                        ? colors.onErrorContainer
                        : colors.onSecondaryContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _aiStatusMessage!,
                      style: TextStyle(
                        color: _aiStatusIsError
                            ? colors.onErrorContainer
                            : colors.onSecondaryContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _questionsCard(BuildContext context) => _ComposerCard(
    title: 'Questões (${_questions.length})',
    icon: Icons.quiz_outlined,
    action: OutlinedButton.icon(
      onPressed: () => setState(() => _questions.add(_ComposerQuestion())),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Adicionar questão'),
    ),
    child: Column(
      children: [
        for (var index = 0; index < _questions.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _questionCard(context, index),
        ],
      ],
    ),
  );

  Widget _questionCard(BuildContext context, int index) {
    final question = _questions[index];
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: responsiveCardPadding(context),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Questão ${index + 1}',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_questions.length > 1)
                IconButton(
                  tooltip: 'Remover questão',
                  onPressed: () => setState(() {
                    _questions.removeAt(index).dispose();
                  }),
                  icon: Icon(Icons.delete_outline_rounded, color: colors.error),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final width = wide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String>(
                      initialValue: question.style,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Estilo da questão',
                      ),
                      items: _questionStyles
                          .map(
                            (style) => DropdownMenuItem(
                              value: style,
                              child: Text(style),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => question.style = value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _textField(
                      controller: question.prompt,
                      label: 'Pergunta',
                      hint: 'Digite o enunciado',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe o enunciado'
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (_usesOptions(question.style))
            _optionsEditor(context, question)
          else
            _textField(
              controller: question.expectedAnswer,
              label: 'Gabarito / resposta esperada',
              hint: 'Informe a resposta ou os critérios esperados',
              maxLines: 3,
            ),
        ],
      ),
    );
  }

  Widget _optionsEditor(BuildContext context, _ComposerQuestion question) {
    final colors = Theme.of(context).colorScheme;
    final options = question.options
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Opções de resposta',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            final width = wide
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (var index = 0; index < question.options.length; index++)
                  SizedBox(
                    width: width,
                    child: _textField(
                      controller: question.options[index],
                      label: 'Opção ${String.fromCharCode(65 + index)}',
                      hint: 'Digite uma resposta',
                      onChanged: (_) => setState(() {
                        if (question.correctAnswer != null &&
                            !question.options.any(
                              (item) =>
                                  item.text.trim() == question.correctAnswer,
                            )) {
                          question.correctAnswer = null;
                        }
                      }),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: options.contains(question.correctAnswer)
              ? question.correctAnswer
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Resposta correta'),
          hint: const Text('Escolha uma opção válida'),
          items: options
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          validator: (value) =>
              value == null ? 'Selecione a resposta correta' : null,
          onChanged: (value) => setState(() => question.correctAnswer = value),
        ),
      ],
    );
  }

  Widget _formActions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        final width = wide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: OutlinedButton.icon(
                onPressed: _preview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Pré-visualizar (Professor)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: width,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Publicando...' : 'Salvar e publicar'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7651C8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _publishedExercises(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _ComposerCard(
      title: 'Conteúdos publicados',
      icon: Icons.library_books_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.dataLoadError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.dataLoadError!,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            TextButton.icon(
              onPressed: widget.onSaved,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Atualizar'),
            ),
          ],
          if (widget.exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.dataLoadError == null
                    ? 'Não há atividades registradas no banco de dados para este professor. Atualize para consultar novamente.'
                    : 'Nenhuma atividade carregada.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            )
          else
            for (final exercise in widget.exercises)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                title: Text('${exercise['title'] ?? 'Conteúdo'}'),
                subtitle: Text(
                  [
                        exercise['category'],
                        exercise['theme'],
                        exercise['schoolClassName'],
                        exercise['languageName'],
                      ]
                      .where(
                        (value) =>
                            value != null && value.toString().trim().isNotEmpty,
                      )
                      .join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '${(exercise['questions'] as List? ?? []).length} questões',
                ),
              ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label, hintText: hint),
    maxLines: maxLines,
    keyboardType: keyboardType,
    validator: validator,
    onChanged: onChanged,
  );

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _ComposerQuestion {
  _ComposerQuestion()
    : style = 'Múltipla Escolha',
      prompt = TextEditingController(),
      expectedAnswer = TextEditingController(),
      options = List.generate(4, (_) => TextEditingController());

  String style;
  final TextEditingController prompt;
  final TextEditingController expectedAnswer;
  final List<TextEditingController> options;
  String? correctAnswer;

  void dispose() {
    prompt.dispose();
    expectedAnswer.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: responsiveCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF7651C8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ContentTypeCard extends StatelessWidget {
  const _ContentTypeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final purple = const Color(0xFF7651C8);
    return Material(
      color: selected ? colors.secondaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? purple : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected
                            ? colors.onSecondaryContainer
                            : colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: selected
                            ? colors.onSecondaryContainer
                            : colors.onSurfaceVariant,
                        fontSize: 12,
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
}
