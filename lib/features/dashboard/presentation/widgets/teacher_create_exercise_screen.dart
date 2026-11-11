import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

class _ClassOption {
  const _ClassOption({required this.id, required this.name});
  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ClassOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
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

  static const _aiPresets = [
    'Simple Past vs Present Perfect',
    'Conversação no Restaurante',
    'Viagem e Aeroporto',
    'Entrevista de Emprego',
    'Preposições de Lugar (In, On, At)',
    'Phrasal Verbs Mais Usados',
    'Vocabulário do Cotidiano',
    'Falsos Cognatos no Inglês',
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
  final ScrollController _scrollController = ScrollController();
  final List<_ClassOption> _availableClasses = [];
  bool _loadingClasses = false;
  bool _contentOnly = false;
  bool _saving = false;
  bool _generatingAi = false;
  bool _showAiStudio = true;
  bool _aiAppendMode = false;
  String _aiQuestionStyle = 'Todos os estilos';
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

  List<String> get _effectiveLanguages {
    final taught = _teacher?.taughtLanguages ?? const [];
    final defaults = [
      'Inglês',
      'Espanhol',
      'Francês',
      'Alemão',
      'Italiano',
      'Japonês',
    ];
    return <String>{...taught, ...defaults}.toList();
  }

  List<String> get _effectiveLevels {
    if (widget.proficiencyLevels.isNotEmpty) {
      return widget.proficiencyLevels;
    }
    return const ['Fácil', 'Médio', 'Difícil'];
  }

  @override
  void initState() {
    super.initState();
    // 1. Initial classes from assignments
    for (final a in _activeAssignments) {
      if (a.schoolClassId != null) {
        _availableClasses.add(
          _ClassOption(id: a.schoolClassId!, name: a.schoolClassName),
        );
      }
    }
    if (_availableClasses.isNotEmpty) {
      _classId = _availableClasses.first.id;
    }

    // 2. Initial language (guaranteed non-null)
    _language = _effectiveLanguages.first;

    // 3. Initial level (guaranteed non-null)
    final levels = _effectiveLevels;
    if (levels.isNotEmpty) {
      _level = levels.first;
    }

    // 4. Fetch available classes from API for admins and teachers
    _fetchClassesFromApi();
  }

  Future<void> _fetchClassesFromApi() async {
    setState(() => _loadingClasses = true);
    try {
      final response = await _dio.get<List<dynamic>>('/api/classes');
      final list = (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final newOptions = <_ClassOption>[];
      for (final c in list) {
        final id = (c['id'] as num?)?.toInt();
        final name = (c['name'] ?? 'Turma $id').toString();
        if (id != null) {
          newOptions.add(_ClassOption(id: id, name: name));
        }
      }
      if (mounted && newOptions.isNotEmpty) {
        setState(() {
          final existingIds = _availableClasses.map((e) => e.id).toSet();
          for (final opt in newOptions) {
            if (!existingIds.contains(opt.id)) {
              _availableClasses.add(opt);
            }
          }
          if (_classId == null && _availableClasses.isNotEmpty) {
            _classId = _availableClasses.first.id;
          }
        });
      }
    } catch (_) {
      // Ignore if offline
    } finally {
      if (mounted) setState(() => _loadingClasses = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    final issues = <String>[];
    final title = _title.text.trim();

    if (title.isEmpty) {
      issues.add('• O título do exercício é obrigatório.');
    }
    if (_classId == null) {
      issues.add('• Selecione a turma que receberá a atividade.');
    }
    if (_language == null || _language!.isEmpty) {
      issues.add('• Selecione o idioma da atividade.');
    }
    if (_level == null || _level!.isEmpty) {
      issues.add('• Selecione o nível de dificuldade.');
    }

    if (_contentOnly) {
      if (_content.text.trim().isEmpty && _mediaUrl.text.trim().isEmpty) {
        issues.add(
          '• Informe o texto teórico ou um link de mídia para o conteúdo.',
        );
      }
    } else {
      if (_questions.isEmpty) {
        issues.add('• Adicione ao menos uma questão na atividade.');
      }
      for (var index = 0; index < _questions.length; index++) {
        final q = _questions[index];
        final qNum = index + 1;
        if (q.prompt.text.trim().isEmpty) {
          issues.add('• Questão $qNum: Informe o enunciado (pergunta).');
        }
        if (_usesOptions(q.style)) {
          final opts = q.options
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toSet();
          if (opts.length < 2) {
            issues.add(
              '• Questão $qNum: Preencha ao menos 2 opções de resposta.',
            );
          }
          if (q.correctAnswer == null || !opts.contains(q.correctAnswer)) {
            if (opts.isNotEmpty) {
              q.correctAnswer = opts.first;
            } else {
              issues.add(
                '• Questão $qNum: Selecione a resposta correta (gabarito).',
              );
            }
          }
        } else if (q.expectedAnswer.text.trim().isEmpty) {
          issues.add(
            '• Questão $qNum: Informe o gabarito ou resposta esperada.',
          );
        }
      }
    }

    if (issues.isNotEmpty) {
      _formKey.currentState?.validate();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
      _showValidationDialog(issues);
      return;
    }

    setState(() => _saving = true);
    try {
      final dueDateStr = _dueDate == null
          ? null
          : '${_dueDate!.year.toString().padLeft(4, '0')}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}';

      await _dio.post(
        '/api/exercises',
        data: {
          'title': title,
          'category': _category,
          'theme': _theme.text.trim(),
          'languageName': _language,
          'proficiencyLevel': _level,
          'description': _description.text.trim(),
          'contentBody': _contentOnly ? _content.text.trim() : null,
          'mediaUrl': _mediaUrl.text.trim().isEmpty
              ? null
              : _mediaUrl.text.trim(),
          'dueDate': dueDateStr,
          'schoolClassId': _classId,
          'questions': _contentOnly
              ? <Map<String, dynamic>>[]
              : _questions.map(_questionToJson).toList(),
        },
      );

      if (!mounted) return;
      await widget.onSaved();
      if (!mounted) return;
      _showSuccessDialog(title);
    } catch (error) {
      if (mounted) {
        _showErrorDialog(_errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showValidationDialog(List<String> issues) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFE5902D),
          size: 40,
        ),
        title: const Text(
          'Campos Pendentes',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Para salvar e publicar a atividade, corrija os itens abaixo:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                for (final issue in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      issue,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7651C8),
            ),
            child: const Text('Entendido, vou preencher'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF2EB872),
          size: 52,
        ),
        title: const Text(
          'Atividade Publicada! 🎉',
          style: TextStyle(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            'A atividade "$title" foi salva e publicada com sucesso para a turma!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetForm();
            },
            child: const Text('Criar outra atividade'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onBack();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7651C8),
            ),
            child: const Text('Voltar ao Painel'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFDC2626),
          size: 44,
        ),
        title: const Text(
          'Erro ao Publicar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
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
      controller: _scrollController,
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
                      _contentTypeSelector(context)
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.05, end: 0),
                      const SizedBox(height: 16),
                      _informationCard(context, assignments, teacher)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 60.ms)
                          .slideY(begin: 0.05, end: 0),
                      if (_contentOnly) ...[
                        const SizedBox(height: 16),
                        _theoryCard(context)
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 120.ms)
                            .slideY(begin: 0.05, end: 0),
                      ] else ...[
                        const SizedBox(height: 16),
                        _questionsCard(context)
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 120.ms)
                            .slideY(begin: 0.05, end: 0),
                      ],
                      const SizedBox(height: 16),
                      _formActions(context)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 180.ms)
                          .slideY(begin: 0.05, end: 0),
                      const SizedBox(height: 24),
                      _publishedExercises(context)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 240.ms)
                          .slideY(begin: 0.05, end: 0),
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
            const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 30,
            ),
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
                          _availableClasses.any((c) => c.id == _classId)
                          ? _classId
                          : (_availableClasses.isNotEmpty
                                ? _availableClasses.first.id
                                : null),
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Turma',
                        suffixIcon: _loadingClasses
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      hint: Text(
                        _availableClasses.isEmpty
                            ? (_loadingClasses
                                  ? 'Carregando turmas...'
                                  : 'Nenhuma turma disponível')
                            : 'Selecione a turma',
                      ),
                      items: _availableClasses
                          .map(
                            (c) => DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(
                                c.name,
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
                      initialValue: _effectiveLanguages.contains(_language)
                          ? _language
                          : _effectiveLanguages.first,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Idioma'),
                      items: _effectiveLanguages
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
          if (_availableClasses.isEmpty && !_loadingClasses) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Nenhuma turma disponível encontrada para publicação. Verifique suas atribuições ou crie uma turma.',
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

  void _selectAiPreset(String preset) {
    setState(() {
      _aiInstructions.text = preset;
      if (_theme.text.trim().isEmpty) {
        _theme.text = preset;
      }
      if (_title.text.trim().isEmpty) {
        _title.text = 'Prática: $preset';
      }
    });
  }

  Future<void> _generateWithAi() async {
    final themeText = _theme.text.trim();
    final instructionsText = _aiInstructions.text.trim();
    if (themeText.isEmpty && instructionsText.isEmpty) {
      setState(() {
        _aiStatusIsError = true;
        _aiStatusMessage =
            'Escolha um dos temas sugeridos abaixo ou digite instruções personalizadas para a IA.';
      });
      return;
    }

    setState(() {
      _generatingAi = true;
      _aiStatusMessage = null;
      _aiStatusIsError = false;
    });

    try {
      final List<String> requestedStyles =
          _aiQuestionStyle == 'Todos os estilos'
          ? _questionStyles
          : [_aiQuestionStyle];

      final response = await _dio.post<List<dynamic>>(
        '/api/exercises/generate-ai',
        data: {
          'languageName': _language ?? 'Inglês',
          'proficiencyLevel': _level ?? 'Fácil',
          'category': _category,
          'theme': themeText.isNotEmpty ? themeText : instructionsText,
          'questionCount': _aiQuestionCount,
          'questionStyles': requestedStyles,
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

      if (!_aiAppendMode) {
        for (final old in _questions) {
          old.dispose();
        }
        _questions.clear();
      }

      setState(() {
        _questions.addAll(generated);
        _aiStatusIsError = false;
        _aiStatusMessage = _aiAppendMode
            ? '${generated.length} novas questões foram adicionadas à lista (Total: ${_questions.length})!'
            : '${generated.length} questões geradas com sucesso! Revise e ajuste cada uma abaixo.';
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

  Future<void> _generateOptionsWithAi(_ComposerQuestion question) async {
    final prompt = question.prompt.text.trim();
    if (prompt.isEmpty) {
      _showMessage(
        'Digite o enunciado da questão para a IA sugerir alternativas.',
      );
      return;
    }
    setState(() => question.generatingOptions = true);
    try {
      final response = await _dio.post<dynamic>(
        '/api/exercises/generate-options-ai',
        data: {
          'question': prompt,
          'correctAnswer': question.correctAnswer ?? '',
          'languageName': _language ?? 'Inglês',
        },
      );
      final rawList = response.data as List<dynamic>? ?? const [];
      final distractors = rawList
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (distractors.isNotEmpty) {
        final currentCorrect = question.correctAnswer?.trim();
        final optionsPool = <String>[];
        if (currentCorrect != null && currentCorrect.isNotEmpty) {
          optionsPool.add(currentCorrect);
        }
        for (final d in distractors) {
          if (!optionsPool.contains(d) && optionsPool.length < 4) {
            optionsPool.add(d);
          }
        }
        while (optionsPool.length < 4 &&
            distractors.length > optionsPool.length) {
          optionsPool.add(distractors[optionsPool.length]);
        }
        for (
          var i = 0;
          i < question.options.length && i < optionsPool.length;
          i++
        ) {
          question.options[i].text = optionsPool[i];
        }
        if (question.correctAnswer == null ||
            !optionsPool.contains(question.correctAnswer)) {
          question.correctAnswer = optionsPool.first;
        }
        _showMessage('Alternativas geradas com sucesso pela IA!');
      } else {
        _showMessage('A IA não retornou opções adicionais.');
      }
    } catch (e) {
      _showMessage('Erro ao gerar alternativas: ${_errorMessage(e)}');
    } finally {
      if (mounted) setState(() => question.generatingOptions = false);
    }
  }

  Future<void> _generateExplanationWithAi(_ComposerQuestion question) async {
    final prompt = question.prompt.text.trim();
    final answer = (question.correctAnswer ?? question.expectedAnswer.text)
        .trim();
    if (prompt.isEmpty) {
      _showMessage('Informe o enunciado da pergunta primeiro.');
      return;
    }
    setState(() => question.generatingExplanation = true);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/exercises/explain-ai',
        data: {
          'question': prompt,
          'correctAnswer': answer,
          'languageName': _language ?? 'Inglês',
        },
      );
      final expl = response.data?['explanation']?.toString();
      if (expl != null && expl.isNotEmpty) {
        setState(() => question.aiExplanation = expl);
        _showMessage('Explicação pedagógica gerada pela IA!');
      }
    } catch (e) {
      _showMessage('Erro ao obter explicação: ${_errorMessage(e)}');
    } finally {
      if (mounted) setState(() => question.generatingExplanation = false);
    }
  }

  Widget _aiStudioPanel(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7651C8).withValues(alpha: 0.12),
            colors.primary.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF7651C8).withValues(alpha: 0.35),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF7651C8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estúdio IA no Menu de Questões',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gere ou expanda o questionário automaticamente com Gemini 3.5 Flash',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Substituir lista'),
                    selected: !_aiAppendMode,
                    selectedColor: const Color(
                      0xFF7651C8,
                    ).withValues(alpha: 0.25),
                    onSelected: (val) => setState(() => _aiAppendMode = !val),
                  ),
                  ChoiceChip(
                    label: const Text('Adicionar ao fim'),
                    selected: _aiAppendMode,
                    selectedColor: const Color(
                      0xFF7651C8,
                    ).withValues(alpha: 0.25),
                    onSelected: (val) => setState(() => _aiAppendMode = val),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Temas rápidos recomendados:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _aiPresets.map((preset) {
              final isSelected = _aiInstructions.text.trim() == preset;
              return ActionChip(
                label: Text(preset, style: const TextStyle(fontSize: 12)),
                avatar: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.auto_awesome,
                  size: 14,
                  color: isSelected ? Colors.white : const Color(0xFF7651C8),
                ),
                backgroundColor: isSelected
                    ? const Color(0xFF7651C8)
                    : colors.surfaceContainerHigh,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : colors.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF7651C8)
                      : colors.outlineVariant,
                ),
                onPressed: () => _selectAiPreset(preset),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 600;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: wide
                        ? (constraints.maxWidth - 340)
                        : constraints.maxWidth,
                    child: _textField(
                      controller: _aiInstructions,
                      label: 'Instruções / Foco da IA',
                      hint: 'Ex: Focar no Simple Past com verbos irregulares',
                    ),
                  ),
                  SizedBox(
                    width: wide ? 160 : (constraints.maxWidth - 12) / 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _aiQuestionCount,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
                      ),
                      items: const [1, 2, 3, 4, 5, 6, 8, 10]
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
                  SizedBox(
                    width: wide ? 156 : (constraints.maxWidth - 12) / 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _aiQuestionStyle,
                      decoration: const InputDecoration(labelText: 'Estilo'),
                      items: ['Todos os estilos', ..._questionStyles]
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _aiQuestionStyle = val);
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                    ? 'Gerando com IA...'
                    : '✨ Gerar $_aiQuestionCount questões com IA',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
                    : const Color(0xFF7651C8).withValues(alpha: 0.15),
                border: Border.all(
                  color: _aiStatusIsError
                      ? colors.error
                      : const Color(0xFF7651C8).withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _aiStatusIsError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_rounded,
                    color: _aiStatusIsError
                        ? colors.onErrorContainer
                        : const Color(0xFF7651C8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _aiStatusMessage!,
                      style: TextStyle(
                        color: _aiStatusIsError
                            ? colors.onErrorContainer
                            : colors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.04, end: 0);
  }

  Widget _questionsCard(BuildContext context) => _ComposerCard(
    title: 'Questões (${_questions.length})',
    icon: Icons.quiz_outlined,
    action: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => setState(() => _showAiStudio = !_showAiStudio),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF7651C8),
            side: const BorderSide(color: Color(0xFF7651C8), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(
            _showAiStudio
                ? Icons.keyboard_arrow_up_rounded
                : Icons.auto_awesome_rounded,
            size: 18,
          ),
          label: Text(
            _showAiStudio ? 'Ocultar Estúdio IA' : '✨ Gerar com IA',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        FilledButton.icon(
          onPressed: () => setState(() => _questions.add(_ComposerQuestion())),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Nova questão'),
        ),
      ],
    ),
    child: Column(
      children: [
        if (_showAiStudio) ...[
          _aiStudioPanel(context),
          const SizedBox(height: 16),
        ],
        for (var index = 0; index < _questions.length; index++) ...[
          if (index > 0) const SizedBox(height: 14),
          _questionCard(context, index)
              .animate()
              .fadeIn(duration: 350.ms, delay: (index * 50).ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Questão ${index + 1}',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  question.style,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (_usesOptions(question.style)) ...[
                TextButton.icon(
                  onPressed: question.generatingOptions
                      ? null
                      : () => _generateOptionsWithAi(question),
                  icon: question.generatingOptions
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text(
                    'Alternativas IA',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7651C8),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              TextButton.icon(
                onPressed: question.generatingExplanation
                    ? null
                    : () => _generateExplanationWithAi(question),
                icon: question.generatingExplanation
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lightbulb_outline_rounded, size: 16),
                label: const Text(
                  'Explicar Gabarito',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amber.shade800,
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
          const SizedBox(height: 12),
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
          if (question.aiExplanation != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7651C8).withValues(alpha: 0.12),
                    colors.primary.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF7651C8).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    color: Color(0xFF7651C8),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💡 Explicação Pedagógica da IA:',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF7651C8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          question.aiExplanation!,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurface,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    tooltip: 'Ocultar explicação',
                    onPressed: () =>
                        setState(() => question.aiExplanation = null),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0),
          ],
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
              : (options.isNotEmpty ? options.first : null),
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Resposta correta (Gabarito)',
          ),
          hint: const Text('Escolha a opção correta'),
          items: options
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.rocket_launch_rounded),
                label: Text(
                  _saving ? 'Publicando no servidor...' : 'Salvar e publicar',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
  String? aiExplanation;
  bool generatingOptions = false;
  bool generatingExplanation = false;

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
