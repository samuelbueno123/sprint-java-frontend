import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/audio/system_sound_service.dart';
import 'package:frontend/core/constants/app_feedback_widgets.dart';
import 'package:frontend/core/constants/supported_languages.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/ui/language_flag.dart';
import 'package:frontend/core/ui/mascot/mascot.dart';
import 'package:frontend/core/ui/vivid_icon_palette.dart';
import '../learning_features.dart';
import '../responsive_layout.dart';

class PersonalizedLearningPathView extends StatefulWidget {
  const PersonalizedLearningPathView({
    super.key,
    required this.onBack,
    this.dio,
    this.initialLanguage = kDefaultSupportedLanguage,
    this.enrolledLanguages,
  });

  final VoidCallback onBack;
  final Dio? dio;
  final String initialLanguage;
  final List<String>? enrolledLanguages;

  @override
  State<PersonalizedLearningPathView> createState() =>
      _PersonalizedLearningPathViewState();
}

class _PersonalizedLearningPathViewState
    extends State<PersonalizedLearningPathView> {
  late final Dio _dio = widget.dio ?? ApiClient().dio;
  late Future<void> _loadFuture;

  Map<String, dynamic>? _pathData;
  List<Map<String, dynamic>> _modules = [];
  List<String> _availableLanguages = [];
  late String _selectedLanguage = SupportedLanguages.normalizeOrDefault(
    widget.initialLanguage,
    kDefaultSupportedLanguage,
  );
  LearningExerciseSessionData? _activeModuleExercise;
  int? _activeModuleId;
  bool _submitting = false;
  String? _error;

  List<String> get _visibleLanguages {
    if (_availableLanguages.isNotEmpty) {
      return _availableLanguages;
    }
    final propLangs = <String>[];
    for (final raw in widget.enrolledLanguages ?? const <String>[]) {
      final norm = SupportedLanguages.normalize(raw);
      if (norm != null && !propLangs.contains(norm)) {
        propLangs.add(norm);
      }
    }
    if (propLangs.isNotEmpty) {
      return propLangs;
    }
    return [_selectedLanguage];
  }

  @override
  void initState() {
    super.initState();
    final initialEnrolled = <String>[];
    for (final raw in widget.enrolledLanguages ?? const <String>[]) {
      final norm = SupportedLanguages.normalize(raw);
      if (norm != null && !initialEnrolled.contains(norm)) {
        initialEnrolled.add(norm);
      }
    }
    if (initialEnrolled.isNotEmpty &&
        !initialEnrolled.contains(_selectedLanguage)) {
      _selectedLanguage = initialEnrolled.first;
    }
    _loadFuture = _loadPath();
  }

  Future<void> _loadPath({String? language}) async {
    final targetLang = language ?? _selectedLanguage;
    setState(() => _error = null);
    try {
      final res = await _dio.get(
        '/api/learning-path/me',
        queryParameters: {'language': targetLang},
      );
      if (!mounted) return;
      final data = Map<String, dynamic>.from(res.data as Map);
      final rawAvailable = (data['availableLanguages'] as List?) ?? const [];
      final parsedAvailable = <String>[];
      for (final item in rawAvailable) {
        final norm = SupportedLanguages.normalize(item?.toString());
        if (norm != null && !parsedAvailable.contains(norm)) {
          parsedAvailable.add(norm);
        }
      }
      final normalizedLang = SupportedLanguages.normalizeOrDefault(
        data['language']?.toString(),
        targetLang,
      );
      if (language == null &&
          parsedAvailable.isNotEmpty &&
          !parsedAvailable.contains(normalizedLang)) {
        _availableLanguages = parsedAvailable;
        await _loadPath(language: parsedAvailable.first);
        return;
      }
      setState(() {
        _pathData = data;
        if (parsedAvailable.isNotEmpty) {
          _availableLanguages = parsedAvailable;
        }
        _selectedLanguage = normalizedLang;
        _modules = ((data['modules'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
      MascotController.instance.updateNavigationContext(
        languageCode: normalizedLang,
      );
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
          'language': _pathData?['language'] ?? _selectedLanguage,
          'dailyGoalMinutes': minutes,
          'targetCefrLevel': _pathData?['targetCefrLevel'] ?? 'B2',
        },
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      SystemSoundService.pop();
      if (!mounted) return;
      setState(() {
        _pathData = data;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meta diária ajustada para $minutes minutos.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar meta.')),
        );
      }
    }
  }

  Future<void> _openModuleSession(Map<String, dynamic> module) async {
    final moduleId = (module['moduleId'] as num?)?.toInt();
    if (moduleId == null) return;
    final moduleTitle = module['title']?.toString() ?? 'Módulo';
    final moduleLevel = module['cefrLevel']?.toString() ?? 'A1';
    final moduleCategory = module['category']?.toString() ?? 'Trilha';
    final moduleDescription = module['description']?.toString();

    setState(() => _submitting = true);
    List<Map<String, dynamic>> rawQuestions = [];
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/learning-path/modules/$moduleId/quiz',
      );
      rawQuestions = (res.data ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar prática do módulo.')),
        );
      }
      if (mounted) setState(() => _submitting = false);
      return;
    }

    if (!mounted) return;
    if (rawQuestions.isEmpty) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este módulo ainda não possui questões disponíveis.'),
        ),
      );
      return;
    }

    final sessionQuestions = rawQuestions.map((q) {
      final options = ((q['options'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      final qCat = q['category']?.toString().trim();
      final qStyle = (qCat != null && qCat.isNotEmpty)
          ? '$moduleLevel • $qCat'
          : '$moduleLevel • $moduleCategory';
      final rawTip =
          (q['mascotHelpMessage'] ?? q['mascot_help_message'])
              ?.toString()
              .trim();
      return LearningExerciseQuestionData(
        q['prompt']?.toString() ?? '',
        options,
        style: qStyle,
        mascotHelpMessage: (rawTip != null && rawTip.isNotEmpty)
            ? rawTip
            : 'Prática adaptativa em $_selectedLanguage ($moduleTitle). Leia com atenção!',
      );
    }).toList();

    setState(() {
      _submitting = false;
      _activeModuleId = moduleId;
      _activeModuleExercise = LearningExerciseSessionData(
        id: moduleId,
        title: moduleTitle,
        language: _selectedLanguage,
        level: moduleLevel,
        className: 'Trilha Personalizada',
        category: moduleCategory,
        theme: _selectedLanguage,
        teacher: 'Trilha CEFR Duolinfo',
        description: moduleDescription,
        questions: sessionQuestions,
      );
    });
  }

  Future<void> _showDiagnosticDialog({String? initialLanguage}) async {
    String diagLang = initialLanguage ?? _selectedLanguage;
    List<Map<String, dynamic>> questions = [];
    try {
      final res = await _dio.get(
        '/api/learning-path/diagnostic',
        queryParameters: {'language': diagLang},
      );
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

    final diagToken = MascotController.instance.enterActivity(
      activityId: 'diagnostic:$diagLang',
      title: 'Teste Diagnóstico ($diagLang)',
      mascotHelpMessage:
          'Responda no seu ritmo para calibrarmos seu nível CEFR em $diagLang.',
    );

    final answers = <int, int>{};
    int currentQIndex = 0;
    bool saving = false;
    bool reloadingLang = false;
    Map<String, dynamic>? completedResult;

    try {
      await showDialog<void>(
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
            final dialogColors = Theme.of(ctx).colorScheme;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                      '$diagLang • $level • $category',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: diagLang,
                      decoration: const InputDecoration(
                        labelText: 'Idioma do nivelamento',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: (_visibleLanguages.contains(diagLang)
                              ? _visibleLanguages
                              : [diagLang, ..._visibleLanguages])
                          .map(
                            (lang) => DropdownMenuItem(
                              value: lang,
                              child: Row(
                                children: [
                                  LanguageFlag.forLanguage(lang, width: 18),
                                  const SizedBox(width: 8),
                                  Text(lang),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: saving || reloadingLang
                          ? null
                          : (newLang) async {
                              if (newLang == null || newLang == diagLang) {
                                return;
                              }
                              setDialogState(() => reloadingLang = true);
                              try {
                                final r = await _dio.get(
                                  '/api/learning-path/diagnostic',
                                  queryParameters: {'language': newLang},
                                );
                                final newQs = (r.data as List)
                                    .map(
                                      (e) =>
                                          Map<String, dynamic>.from(e as Map),
                                    )
                                    .toList();
                                if (ctx.mounted && newQs.isNotEmpty) {
                                  setDialogState(() {
                                    diagLang = newLang;
                                    questions = newQs;
                                    answers.clear();
                                    currentQIndex = 0;
                                  });
                                  MascotController.instance.updateActivityContext(
                                    diagToken,
                                    mascotHelpMessage:
                                        'Responda no seu ritmo para calibrarmos seu nível CEFR em $newLang.',
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setDialogState(() => reloadingLang = false);
                                }
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                    if (reloadingLang)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      Text(
                        prompt,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...List.generate(options.length, (optIdx) {
                        final isSelected = answers[qId] == optIdx;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isSelected
                                  ? Colors.blue.withValues(alpha: 0.14)
                                  : null,
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.blue
                                    : dialogColors.outlineVariant,
                                width: isSelected ? 2 : 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () =>
                                setDialogState(() => answers[qId] = optIdx),
                            child: Text(
                              options[optIdx],
                              style: TextStyle(
                                color: isSelected
                                    ? dialogColors.primary
                                    : dialogColors.onSurface,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: answers[qId] == null || saving || reloadingLang
                      ? null
                      : () async {
                          if (currentQIndex < questions.length - 1) {
                            setDialogState(() => currentQIndex++);
                          } else {
                            setDialogState(() => saving = true);
                            try {
                              final submitRes = await _dio.post(
                                '/api/learning-path/diagnostic',
                                data: {
                                  'language': diagLang,
                                  'answers': answers.map(
                                    (key, value) =>
                                        MapEntry(key.toString(), value),
                                  ),
                                },
                              );
                              completedResult = Map<String, dynamic>.from(
                                submitRes.data as Map,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving = false);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Erro ao enviar teste diagnóstico.',
                                    ),
                                  ),
                                );
                              }
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
      if (completedResult != null && mounted) {
        SystemSoundService.success();
        MascotController.instance.markActivityCompleted(diagToken);
        unawaited(_loadPath(language: diagLang));
        await _showResultModal(completedResult!);
      }
    } finally {
      MascotController.instance.exitActivity(diagToken);
    }
  }

  Future<void> _showResultModal(Map<String, dynamic> result) {
    final level = result['determinedCefrLevel'] ?? 'A2';
    final summary = result['diagnosticSummary'] ?? '';

    return showDialog<void>(
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
            const MascotSprite(state: MascotState.celebrate, size: 76),
            const SizedBox(height: 12),
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
    if (_activeModuleExercise != null && _activeModuleId != null) {
      final activeModuleId = _activeModuleId!;
      return LearningExerciseRunPage(
        exercise: _activeModuleExercise!,
        dio: _dio,
        onBack: () => setState(() {
          _activeModuleExercise = null;
          _activeModuleId = null;
        }),
        onFinished: () {
          setState(() {
            _activeModuleExercise = null;
            _activeModuleId = null;
            _loadFuture = _loadPath(language: _selectedLanguage);
          });
        },
        onSubmitCustom: (answers, selectedOptionIndices) async {
          final ordered = [
            for (var i = 0; i < _activeModuleExercise!.questions.length; i++)
              selectedOptionIndices[i] ?? 0,
          ];
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/learning-path/modules/$activeModuleId/quiz-submit',
            data: {'selectedIndices': ordered},
          );
          final d = res.data ?? const {};
          final passed = d['passed'] == true;
          final totalCount =
              (d['totalCount'] as num?)?.toInt() ??
              _activeModuleExercise!.questions.length;
          final correctCount = (d['correctCount'] as num?)?.toInt() ?? 0;
          final xpEarned = (d['xpEarned'] as num?)?.toInt() ?? 0;
          if (passed) {
            SystemSoundService.success();
          } else {
            SystemSoundService.defeat();
          }
          unawaited(_loadPath(language: _selectedLanguage));
          return <String, dynamic>{
            'passed': passed,
            'correctCount': correctCount,
            'questionCount': totalCount,
            'xpEarned': xpEarned,
            'feedback': d['feedback']?.toString() ?? '',
            'reviewStatus': passed ? 'REVIEWED' : 'AUTO_GRADED',
            'questionFeedback': d['questionFeedback'] ?? const [],
          };
        },
      );
    }

    final colors = Theme.of(context).colorScheme;

    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoader(
            message: 'Calculando sua trilha CEFR adaptativa...',
          );
        }

        if (_error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppErrorIllustration(size: 74),
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
          padding: responsivePagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive Header
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
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trilha de Aprendizagem Personalizada',
                              style: TextStyle(
                                fontSize: isCompactLayout(context) ? 19 : 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Currículo adaptativo referenciado no CEFR de A1 a C2.',
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
                  FilledButton.tonalIcon(
                    onPressed: () => _showDiagnosticDialog(
                      initialLanguage: _selectedLanguage,
                    ),
                    icon: const Icon(Icons.quiz_rounded, size: 18),
                    label: const Text('Fazer Teste de Nivelamento'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: _visibleLanguages.map((lang) {
                  return ChoiceChip(
                    selected: _selectedLanguage == lang,
                    avatar: LanguageFlag.forLanguage(lang, width: 18),
                    label: Text(lang),
                    onSelected: (selected) {
                      if (selected && _selectedLanguage != lang) {
                        setState(() {
                          _selectedLanguage = lang;
                          _modules = [];
                          _loadFuture = _loadPath(language: lang);
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              AppInfoBanner(
                title:
                    'Rumo ao nível $targetCefr ($cefr atual • $_selectedLanguage)',
                message:
                    'Você está com $streak dia(s) de ofensiva. Conclua cada módulo prático (≥ 60%) para evoluir na sua meta de $dailyGoal min/dia!',
                icon: Icons.route_rounded,
                accentColor: const Color(0xFF3579E8),
              ),
              const SizedBox(height: 18),

              // Responsive Overview Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 660;
                  final cardWidth = wide
                      ? (constraints.maxWidth - 32) / 3
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _buildCard(
                          title: 'Nível Atual',
                          value: '$cefr ➔ $targetCefr',
                          subtitle: 'Objetivo Alvo',
                          icon: Icons.flag_rounded,
                          color: const Color(0xFF3579E8),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildCard(
                          title: 'Ofensiva Ativa',
                          value: '$streak dias',
                          subtitle: 'Sequência diária',
                          icon: Icons.local_fire_department_rounded,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildCard(
                          title: 'Progresso da Trilha',
                          value: '${overallProgress.toStringAsFixed(0)}%',
                          subtitle: 'Módulos concluídos',
                          icon: Icons.auto_graph_rounded,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Responsive Daily Goal Selector
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: VividIconPalette.colorFor(
                            Icons.schedule_rounded,
                            brightness: Theme.of(context).brightness,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Meta Diária de Estudo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Defina um ritmo sustentável para seu aprendizado contínuo.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 5, label: Text('5m')),
                        ButtonSegment(value: 15, label: Text('15m')),
                        ButtonSegment(value: 30, label: Text('30m')),
                      ],
                      selected: {
                        const {5, 15, 30}.contains(dailyGoal) ? dailyGoal : 15,
                      },
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
          Expanded(
            child: Column(
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
          ),
        ],
      ),
    );
  }

  Widget _buildCompetenceGrid(ColorScheme colors) {
    final gram = ((_pathData?['grammarCompetence'] as num?)?.toDouble() ?? 0.0)
        .clamp(0.0, 100.0);
    final voc =
        ((_pathData?['vocabularyCompetence'] as num?)?.toDouble() ?? 0.0)
            .clamp(0.0, 100.0);
    final list =
        ((_pathData?['listeningCompetence'] as num?)?.toDouble() ?? 0.0)
            .clamp(0.0, 100.0);
    final spk = ((_pathData?['speakingCompetence'] as num?)?.toDouble() ?? 0.0)
        .clamp(0.0, 100.0);
    final read = ((_pathData?['readingCompetence'] as num?)?.toDouble() ?? 0.0)
        .clamp(0.0, 100.0);
    final writ = ((_pathData?['writingCompetence'] as num?)?.toDouble() ?? 0.0)
        .clamp(0.0, 100.0);
    final avgComp = (gram + voc + list + spk + read + writ) / 6.0;
    final hasAnyProgress = avgComp > 0.5;
    final rawMetrics = _pathData?['activityMetrics'];
    final metrics = rawMetrics is Map
        ? Map<String, dynamic>.from(rawMetrics)
        : const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Média em $_selectedLanguage: ${avgComp.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: colors.primary,
                      ),
                    ),
                    Text(
                      'Escala real: 0% a 100%',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 255,
                  child: RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.polygon,
                      tickCount: 4,
                      radarTouchData: RadarTouchData(enabled: true),
                      ticksTextStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                      gridBorderData: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.6),
                      ),
                      radarBorderData: BorderSide(color: colors.outlineVariant),
                      tickBorderData: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.35),
                      ),
                      titlePositionPercentageOffset: 0.2,
                      titleTextStyle: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      getTitle: (index, angle) {
                        final titles = [
                          'Gramática\n${gram.toStringAsFixed(0)}%',
                          'Vocabulário\n${voc.toStringAsFixed(0)}%',
                          'Audição\n${list.toStringAsFixed(0)}%',
                          'Fala\n${spk.toStringAsFixed(0)}%',
                          'Leitura\n${read.toStringAsFixed(0)}%',
                          'Escrita\n${writ.toStringAsFixed(0)}%',
                        ];
                        return RadarChartTitle(
                          text: titles[index % titles.length],
                        );
                      },
                      dataSets: [
                        // Invisible 0-to-100 scale anchors so the polygon never auto-stretches small scores to 100%.
                        RadarDataSet(
                          fillColor: Colors.transparent,
                          borderColor: Colors.transparent,
                          borderWidth: 0,
                          entryRadius: 0,
                          dataEntries: const [
                            RadarEntry(value: 0),
                            RadarEntry(value: 0),
                            RadarEntry(value: 0),
                            RadarEntry(value: 0),
                            RadarEntry(value: 0),
                            RadarEntry(value: 0),
                          ],
                        ),
                        RadarDataSet(
                          fillColor: Colors.transparent,
                          borderColor: Colors.transparent,
                          borderWidth: 0,
                          entryRadius: 0,
                          dataEntries: const [
                            RadarEntry(value: 100),
                            RadarEntry(value: 100),
                            RadarEntry(value: 100),
                            RadarEntry(value: 100),
                            RadarEntry(value: 100),
                            RadarEntry(value: 100),
                          ],
                        ),
                        RadarDataSet(
                          fillColor: const Color(
                            0xFF3579E8,
                          ).withValues(alpha: 0.28),
                          borderColor: const Color(0xFF3579E8),
                          borderWidth: 2.5,
                          entryRadius: 4,
                          dataEntries: [
                            RadarEntry(value: gram),
                            RadarEntry(value: voc),
                            RadarEntry(value: list),
                            RadarEntry(value: spk),
                            RadarEntry(value: read),
                            RadarEntry(value: writ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (metrics.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      _MetricSourceChip(
                        icon: Icons.bolt_rounded,
                        label: '${metrics['languageXp'] ?? 0} XP em $_selectedLanguage',
                        color: Colors.amber.shade800,
                      ),
                      _MetricSourceChip(
                        icon: Icons.school_rounded,
                        label:
                            'Módulos: ${metrics['modulesCompleted'] ?? 0}/${metrics['modulesTotal'] ?? _modules.length}',
                        color: Colors.blue.shade700,
                      ),
                      _MetricSourceChip(
                        icon: Icons.assignment_turned_in_rounded,
                        label:
                            'Atividades: ${metrics['exerciseSubmissions'] ?? 0}',
                        color: Colors.green.shade700,
                      ),
                      _MetricSourceChip(
                        icon: Icons.style_rounded,
                        label: 'Revisões SRS: ${metrics['srsReviewed'] ?? 0}',
                        color: Colors.purple.shade700,
                      ),
                      _MetricSourceChip(
                        icon: Icons.mic_rounded,
                        label:
                            'Prática Oral: ${metrics['pronunciationAttempts'] ?? 0}',
                        color: Colors.orange.shade800,
                      ),
                      _MetricSourceChip(
                        icon: Icons.forum_rounded,
                        label:
                            'Turnos IA: ${metrics['aiConversationTurns'] ?? 0}',
                        color: Colors.indigo.shade700,
                      ),
                    ],
                  ),
                ],
                if (!hasAnyProgress) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Nenhuma prática concluída em $_selectedLanguage ainda. '
                      'Faça o teste de nivelamento, conclua um módulo abaixo ou pratique exercícios neste idioma para ver seu gráfico crescer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = constraints.maxWidth >= 540;
            final itemWidth = twoCols
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _buildCompetenceBar('Gramática', gram, Colors.blue),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildCompetenceBar('Vocabulário', voc, Colors.purple),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildCompetenceBar(
                    'Audição (Listening)',
                    list,
                    Colors.teal,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildCompetenceBar(
                    'Fala (Speaking)',
                    spk,
                    Colors.orange,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildCompetenceBar(
                    'Leitura (Reading)',
                    read,
                    Colors.green,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildCompetenceBar(
                    'Escrita (Writing)',
                    writ,
                    Colors.indigo,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompetenceBar(String label, double value, Color color) {
    final targetVal = value.clamp(0.0, 100.0);
    return TweenAnimationBuilder<double>(
      key: ValueKey('$_selectedLanguage:$label'),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: targetVal),
      builder: (context, animatedValue, _) {
        return Container(
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
                    '${animatedValue.toStringAsFixed(0)}%',
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
                value: animatedValue / 100.0,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
                minHeight: 7,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModuleTile(
    ColorScheme colors,
    Map<String, dynamic> m,
    int index,
  ) {
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
        child: Wrap(
          spacing: 14,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
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
              ],
            ),
            if (isProgress)
              FilledButton.icon(
                onPressed: _submitting ? null : () => _openModuleSession(m),
                icon: const Icon(Icons.play_lesson_rounded, size: 16),
                label: const Text('Praticar & Concluir'),
              )
            else if (isCompleted)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : () => _openModuleSession(m),
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: const Text('Praticar Novamente'),
                  ),
                  Icon(
                    Icons.verified_rounded,
                    color: VividIconPalette.green,
                  ),
                ],
              )
            else
              Icon(Icons.lock_outline_rounded, color: colors.outline),
          ],
        ),
      ),
    );
  }
}

class _MetricSourceChip extends StatelessWidget {
  const _MetricSourceChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
