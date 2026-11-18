import 'package:flutter/material.dart';
import '../../../../core/ui/mascot/mascot.dart';
import 'audio_speech_helper.dart';
import 'responsive_layout.dart';

/// Screen that renders the exercise preview for teachers matching the visual specification.
/// Displays questions with answer keys (gabarito), option highlights, explanations, and metadata.
class TeacherExercisePreviewScreen extends StatefulWidget {
  const TeacherExercisePreviewScreen({
    super.key,
    required this.title,
    required this.category,
    required this.theme,
    this.level,
    this.language = 'Inglês',
    required this.questions,
    this.contentBody,
    this.mascotHelpMessage,
    this.onBack,
  });

  final String title;
  final String category;
  final String theme;
  final String? level;
  final String language;
  final List<dynamic> questions;
  final String? contentBody;
  final String? mascotHelpMessage;
  final VoidCallback? onBack;

  @override
  State<TeacherExercisePreviewScreen> createState() =>
      _TeacherExercisePreviewScreenState();
}

class _TeacherExercisePreviewScreenState
    extends State<TeacherExercisePreviewScreen> {
  final Set<int> _expandedGabaritos = {};
  Object? _mascotToken;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      _mascotToken = MascotController.instance.enterActivity(
        activityId: 'preview:${widget.title}',
        title: widget.title.trim().isEmpty
            ? 'Pré-visualização'
            : widget.title.trim(),
        mascotHelpMessage: widget.mascotHelpMessage,
      );
    });
  }

  @override
  void didUpdateWidget(covariant TeacherExercisePreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mascotHelpMessage != widget.mascotHelpMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _disposed || _mascotToken == null) return;
        final trimmed = widget.mascotHelpMessage?.trim() ?? '';
        MascotController.instance.updateActivityContext(
          _mascotToken!,
          mascotHelpMessage: trimmed,
          clearMascotHelpMessage: trimmed.isEmpty,
        );
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final token = _mascotToken;
    if (token != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MascotController.instance.exitActivity(token);
      });
    }
    super.dispose();
  }

  void _toggleGabarito(int index) {
    setState(() {
      if (_expandedGabaritos.contains(index)) {
        _expandedGabaritos.remove(index);
      } else {
        _expandedGabaritos.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qList = _normalizeQuestions(widget.questions);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: responsivePagePadding(context),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Violet Header Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF8B5CF6,
                          ).withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            if (widget.onBack != null) {
                              widget.onBack!();
                            } else {
                              Navigator.maybePop(context);
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Voltar ao Editor',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pré-visualização',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Visão com gabarito e explicações',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Exercise Header Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark
                            ? colors.outlineVariant
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    color: isDark ? colors.surfaceContainer : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title.trim().isEmpty
                                      ? 'Atividade sem título'
                                      : widget.title.trim(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF4C1D95),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _buildBadge(
                                      icon: Icons.menu_book_rounded,
                                      label: widget.category.trim().isEmpty
                                          ? 'Geral'
                                          : widget.category.trim(),
                                      bgColor: const Color(0xFFF3E8FF),
                                      textColor: const Color(0xFF7C3AED),
                                    ),
                                    _buildBadge(
                                      label: widget.theme.trim().isEmpty
                                          ? 'Tema livre'
                                          : widget.theme.trim(),
                                      bgColor: const Color(0xFFF3E8FF),
                                      textColor: const Color(0xFF7C3AED),
                                    ),
                                    _buildBadge(
                                      label: (widget.level ?? '').trim().isEmpty
                                          ? 'Geral'
                                          : widget.level!.trim(),
                                      bgColor: const Color(0xFFFEF3C7),
                                      textColor: const Color(0xFF92400E),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFDDD6FE),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.description_outlined,
                                  color: Color(0xFF7C3AED),
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${qList.length}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                    const Text(
                                      'questões',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Amber Notice Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Esta é a visão do professor. Você pode ver o gabarito e as explicações de cada questão. Clique em "Gabarito" em cada questão para expandir.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (widget.mascotHelpMessage != null &&
                      widget.mascotHelpMessage!.trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(
                            0xFF4F46E5,
                          ).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MascotPoseEmblem(
                            state: MascotState.clickBleat,
                            size: 42,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dica configurada no Bode Branco',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF312E81),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.mascotHelpMessage!.trim(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: isDark
                                        ? const Color(0xFFE2E8F0)
                                        : const Color(0xFF1E1B4B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (widget.contentBody != null &&
                      widget.contentBody!.trim().isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark
                              ? colors.outlineVariant
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      color: isDark ? colors.surfaceContainer : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Texto / Material de Leitura',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              widget.contentBody!.trim(),
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Questions List
                  if (qList.isEmpty)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark
                              ? colors.outlineVariant
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Nenhuma questão cadastrada para esta atividade.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < qList.length; i++) ...[
                      _buildQuestionCard(
                        context: context,
                        question: qList[i],
                        isExpanded: _expandedGabaritos.contains(i),
                        onToggleGabarito: () => _toggleGabarito(i),
                        isDark: isDark,
                        colors: colors,
                      ),
                      if (i < qList.length - 1) const SizedBox(height: 14),
                    ],

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    IconData? icon,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required BuildContext context,
    required _PreviewQuestion question,
    required bool isExpanded,
    required VoidCallback onToggleGabarito,
    required bool isDark,
    required ColorScheme colors,
  }) {
    final styleBadge = _resolveStyleBadge(question.style);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? colors.outlineVariant : const Color(0xFFE2E8F0),
        ),
      ),
      color: isDark ? colors.surfaceContainer : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Number, Style Pill, and Gabarito Toggle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${question.index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7C3AED),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: styleBadge.bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    styleBadge.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: styleBadge.textColor,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onToggleGabarito,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: const Color(0xFF7C3AED),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Gabarito',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7C3AED),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Prompt text
            Text(
              question.prompt.trim().isEmpty
                  ? '(Questão sem enunciado)'
                  : question.prompt.trim(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Audio listening preview (if Áudio style)
            if (styleBadge.label == 'Áudio (Escuta)') ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFEFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA5F3FC)),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.headphones_rounded,
                      color: Color(0xFF0E7490),
                      size: 20,
                    ),
                    Text(
                      question.audioText.trim().isNotEmpty
                          ? 'Frase falada: "${question.audioText.trim()}"'
                          : 'Frase falada: "${question.expectedAnswer.trim().isEmpty ? question.prompt.trim() : question.expectedAnswer.trim()}"',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF155E75),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final text = question.audioText.trim().isNotEmpty
                            ? question.audioText.trim()
                            : (question.expectedAnswer.trim().isNotEmpty
                                  ? question.expectedAnswer.trim()
                                  : question.prompt.trim());
                        AudioSpeechHelper.speak(
                          text,
                          languageName: widget.language,
                        );
                      },
                      icon: const Icon(Icons.volume_up_rounded, size: 16),
                      label: const Text('Ouvir prévia'),
                    ),
                  ],
                ),
              ),
            ],

            // Correspondência pairs
            if (styleBadge.label == 'Correspondência' &&
                question.options.isNotEmpty)
              Column(
                children: [
                  for (final rawPair in question.options) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceContainerLow
                            : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Builder(
                        builder: (context) {
                          final parts = rawPair.contains('=>')
                              ? rawPair.split('=>')
                              : (rawPair.contains('->')
                                    ? rawPair.split('->')
                                    : [rawPair, '']);
                          final left = parts.first.trim();
                          final right = parts.length > 1
                              ? parts.sublist(1).join(' ').trim()
                              : '';
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  left,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(
                                  Icons.compare_arrows_rounded,
                                  color: Color(0xFF4F46E5),
                                  size: 20,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  right,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF4338CA),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              )
            // Options (for multiple choice & true/false questions)
            else if (question.options.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 500;
                  final itemWidth = isWide
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: question.options.map((opt) {
                      final isCorrect = _isCorrectOption(
                        opt,
                        question.expectedAnswer,
                      );
                      return SizedBox(
                        width: itemWidth,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? const Color(0xFFF0FDF4)
                                : (isDark
                                      ? colors.surfaceContainerLow
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCorrect
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFE2E8F0),
                              width: isCorrect ? 1.6 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (isCorrect) ...[
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Color(0xFF22C55E),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  opt,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isCorrect
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    color: isCorrect
                                        ? const Color(0xFF15803D)
                                        : colors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            // Gabarito expandable container
            if (isExpanded) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF7C3AED),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Resposta esperada / Gabarito: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7C3AED),
                                fontSize: 13,
                              ),
                              children: [
                                TextSpan(
                                  text: question.expectedAnswer.trim().isEmpty
                                      ? '(Não especificada)'
                                      : question.expectedAnswer.trim(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4C1D95),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (question.explanation.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Explicação: ${question.explanation.trim()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (question.mascotHelpMessage.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MascotPoseEmblem(
                      state: MascotState.clickBleat,
                      size: 32,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dica do Bode Branco — Questão ${question.index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF312E81),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            question.mascotHelpMessage.trim(),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF1E1B4B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isCorrectOption(String option, String expected) {
    if (expected.trim().isEmpty) return false;
    final optNorm = option.trim().toLowerCase();
    final expNorm = expected.trim().toLowerCase();
    if (optNorm == expNorm) return true;
    // Check if expected is a 1-character letter like A, B, C, D
    if (expNorm.length == 1) {
      final letter = expNorm.toUpperCase();
      if (option.trim().toUpperCase().startsWith('$letter)') ||
          option.trim().toUpperCase().startsWith('$letter -') ||
          option.trim().toUpperCase().startsWith('$letter.')) {
        return true;
      }
    }
    return false;
  }

  _StyleBadgeInfo _resolveStyleBadge(String rawStyle) {
    final s = rawStyle.trim().toUpperCase();
    if (s.contains('VERDADEIRO') ||
        s.contains('FALSO') ||
        s.contains('TRUE_FALSE') ||
        s.contains('TRUE/FALSE')) {
      return _StyleBadgeInfo(
        label: 'Verdadeiro ou Falso',
        bgColor: const Color(0xFFCCFBF1),
        textColor: const Color(0xFF0F766E),
      );
    }
    if (s.contains('CORRESPOND') ||
        s.contains('MATCH') ||
        s.contains('ASSOCI') ||
        s.contains('LIGAR')) {
      return _StyleBadgeInfo(
        label: 'Correspondência',
        bgColor: const Color(0xFFE0E7FF),
        textColor: const Color(0xFF4338CA),
      );
    }
    if (s.contains('AUDIO') || s.contains('ÁUDIO') || s.contains('ESCUTA')) {
      return _StyleBadgeInfo(
        label: 'Áudio (Escuta)',
        bgColor: const Color(0xFFCFFAFE),
        textColor: const Color(0xFF0E7490),
      );
    }
    if (s.contains('MULTIPLE') ||
        s.contains('ESCOLHA') ||
        s.contains('OBJECTIVE')) {
      return _StyleBadgeInfo(
        label: 'Múltipla Escolha',
        bgColor: const Color(0xFFDBEAFE),
        textColor: const Color(0xFF1D4ED8),
      );
    }
    if (s.contains('FILL') || s.contains('COMPLETAR') || s.contains('LACUNA')) {
      return _StyleBadgeInfo(
        label: 'Completar',
        bgColor: const Color(0xFFDCFCE7),
        textColor: const Color(0xFF15803D),
      );
    }
    if (s.contains('DISCURSIVA') ||
        s.contains('OPEN') ||
        s.contains('ABERTA')) {
      return _StyleBadgeInfo(
        label: 'Discursiva',
        bgColor: const Color(0xFFF3E8FF),
        textColor: const Color(0xFF7E22CE),
      );
    }
    if (s.contains('TRANS') || s.contains('TRADU')) {
      return _StyleBadgeInfo(
        label: 'Tradução',
        bgColor: const Color(0xFFFFEDD5),
        textColor: const Color(0xFFC2410C),
      );
    }
    return _StyleBadgeInfo(
      label: rawStyle.isEmpty ? 'Questão' : rawStyle,
      bgColor: const Color(0xFFF1F5F9),
      textColor: const Color(0xFF475569),
    );
  }

  List<_PreviewQuestion> _normalizeQuestions(List<dynamic> rawQuestions) {
    final list = <_PreviewQuestion>[];
    for (var i = 0; i < rawQuestions.length; i++) {
      final q = rawQuestions[i];
      if (q == null) continue;
      String prompt = '';
      String style = '';
      List<String> options = [];
      String expectedAnswer = '';
      String explanation = '';
      String mascotHelpMessage = '';
      String audioText = '';

      if (q is Map) {
        prompt = '${q['prompt'] ?? q['question'] ?? q['text'] ?? ''}';
        style = '${q['style'] ?? q['type'] ?? 'Múltipla Escolha'}';
        expectedAnswer =
            '${q['expectedAnswer'] ?? q['correctAnswer'] ?? q['answer'] ?? ''}';
        explanation = '${q['explanation'] ?? q['rubric'] ?? ''}';
        mascotHelpMessage =
            '${q['mascotHelpMessage'] ?? q['mascot_help_message'] ?? ''}';
        audioText = '${q['audioText'] ?? q['audio_text'] ?? ''}';
        final rawOpts = q['options'];
        if (rawOpts is List) {
          options = rawOpts
              .map((o) {
                if (o is Map) {
                  return '${o['text'] ?? o['label'] ?? o['value'] ?? ''}';
                }
                return '$o';
              })
              .where((o) => o.trim().isNotEmpty)
              .toList();
        }
      } else {
        // Object with fields (like _QuestionDraft or similar)
        try {
          prompt =
              (q.prompt is TextEditingController
                      ? q.prompt.text
                      : '${q.prompt ?? ''}')
                  .toString();
        } catch (_) {
          prompt = '$q';
        }
        try {
          style = '${q.style ?? ''}';
        } catch (_) {}
        try {
          expectedAnswer =
              (q.expectedAnswer is TextEditingController
                      ? q.expectedAnswer.text
                      : '${q.expectedAnswer ?? ''}')
                  .toString();
        } catch (_) {}
        try {
          explanation =
              (q.explanation is TextEditingController
                      ? q.explanation.text
                      : '${q.explanation ?? ''}')
                  .toString();
        } catch (_) {}
        try {
          mascotHelpMessage =
              (q.mascotHelp is TextEditingController
                      ? q.mascotHelp.text
                      : (q.mascotHelpMessage is TextEditingController
                            ? q.mascotHelpMessage.text
                            : '${q.mascotHelpMessage ?? ''}'))
                  .toString();
        } catch (_) {}
        try {
          final rawOpts = q.options;
          if (rawOpts is List) {
            options = rawOpts
                .map((o) {
                  if (o is TextEditingController) return o.text;
                  return '$o';
                })
                .where((o) => o.trim().isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }

      list.add(
        _PreviewQuestion(
          index: i,
          prompt: prompt,
          style: style,
          options: options,
          expectedAnswer: expectedAnswer,
          explanation: explanation,
          mascotHelpMessage: mascotHelpMessage,
          audioText: audioText,
        ),
      );
    }
    return list;
  }
}

class _PreviewQuestion {
  final int index;
  final String prompt;
  final String style;
  final List<String> options;
  final String expectedAnswer;
  final String explanation;
  final String mascotHelpMessage;
  final String audioText;

  _PreviewQuestion({
    required this.index,
    required this.prompt,
    required this.style,
    required this.options,
    required this.expectedAnswer,
    required this.explanation,
    this.mascotHelpMessage = '',
    this.audioText = '',
  });
}

class _StyleBadgeInfo {
  final String label;
  final Color bgColor;
  final Color textColor;

  _StyleBadgeInfo({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });
}
