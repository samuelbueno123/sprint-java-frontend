import 'package:flutter/material.dart';

import 'mascot_assets.dart';
import 'mascot_chat_service.dart';
import 'mascot_controller.dart';
import 'mascot_sprite_widget.dart';

class MascotChatPopover extends StatefulWidget {
  const MascotChatPopover({
    super.key,
    required this.controller,
    required this.maxWidth,
    required this.maxHeight,
  });

  final MascotController controller;
  final double maxWidth;
  final double maxHeight;

  @override
  State<MascotChatPopover> createState() => _MascotChatPopoverState();
}

class _MascotChatPopoverState extends State<MascotChatPopover> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  int _lastMsgCount = 0;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottomIfNeeded(int count) {
    if (count == _lastMsgCount) return;
    _lastMsgCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submitText([String? preset]) async {
    final text = (preset ?? _inputCtrl.text).trim();
    if (text.isEmpty || widget.controller.isChatSending) return;
    if (preset == null) {
      _inputCtrl.clear();
    }
    await widget.controller.sendChatMessage(text);
  }

  List<String> _quickSuggestions(String role) {
    if (role == 'teacher') {
      return const [
        'Como criar atividade com IA?',
        'Onde defino a dica do Bode?',
        'Como corrijo envios dos alunos?',
      ];
    }
    if (role == 'admin') {
      return const [
        'Onde gerencio instituições e turmas?',
        'Como acompanho a saúde do sistema?',
        'Como funcionam os perfis?',
      ];
    }
    return const [
      'Como ganho XP e mantenho a ofensiva?',
      'Onde encontro a Revisão Espaçada?',
      'Como funcionam as atividades e lições?',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activity = widget.controller.currentActivity;

    return Material(
      key: const Key('floating-mascot-popover'),
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(20),
      color: isDark ? const Color(0xFF1A202C) : Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
          minWidth: widget.maxWidth < 260 ? widget.maxWidth : 260,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activity != null
                  ? colors.primary.withValues(alpha: 0.35)
                  : colors.outlineVariant,
            ),
          ),
          child: activity != null
              ? _buildActivityHelpContent(context, colors, isDark, activity)
              : _buildPlatformChatContent(context, colors, isDark),
        ),
      ),
    );
  }

  Widget _buildActivityHelpContent(
    BuildContext context,
    ColorScheme colors,
    bool isDark,
    MascotActivityContext activity,
  ) {
    final isExerciseQuestion =
        activity.activityId?.startsWith('exercise:') == true;
    final hasCustomHelp =
        activity.mascotHelpMessage != null &&
        activity.mascotHelpMessage!.trim().isNotEmpty;
    final helpText = hasCustomHelp
        ? activity.mascotHelpMessage!.trim()
        : (isExerciseQuestion
              ? 'Esta questão ainda não possui uma dica personalizada do professor. Leia o enunciado com atenção, revise as alternativas e use o áudio quando disponível!'
              : 'Este exercício ainda não possui uma dica personalizada do professor. Leia o enunciado com atenção, revise as alternativas e use o áudio quando disponível!');

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MascotPoseEmblem(
                state: activity.isCompleted
                    ? MascotState.fireLoop
                    : MascotState.clickBleat,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isExerciseQuestion
                          ? 'Dica da Questão'
                          : 'Dica da Atividade',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('mascot-popover-close'),
                tooltip: 'Fechar dica',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: widget.controller.closeChat,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasCustomHelp
                      ? colors.primaryContainer.withValues(
                          alpha: isDark ? 0.35 : 0.45,
                        )
                      : colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasCustomHelp
                        ? colors.primary.withValues(alpha: 0.3)
                        : colors.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          hasCustomHelp
                              ? Icons.tips_and_updates_rounded
                              : Icons.info_outline_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hasCustomHelp
                                ? 'Orientação do Professor'
                                : 'Acompanhamento do Bode',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      helpText,
                      key: const Key('mascot-activity-help-text'),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.onSurface,
                        fontWeight: hasCustomHelp
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (activity.isCompleted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: Color(0xFFEA580C),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Atividade concluída — Modo Chama ativo!',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC2410C),
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

  Widget _buildPlatformChatContent(
    BuildContext context,
    ColorScheme colors,
    bool isDark,
  ) {
    final messages = widget.controller.chatMessages;
    final sending = widget.controller.isChatSending;
    final error = widget.controller.chatError;
    _scrollToBottomIfNeeded(messages.length);

    final suggestions = _quickSuggestions(widget.controller.currentUserRole);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          child: Row(
            children: [
              const MascotPoseEmblem(state: MascotState.clickBleat, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bode IA • Guia Duolinfo',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      'Dúvidas sobre a plataforma e navegação',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('mascot-popover-close'),
                tooltip: 'Fechar chat',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: widget.controller.closeChat,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            controller: _scrollCtrl,
            shrinkWrap: true,
            padding: const EdgeInsets.all(12),
            children: [
              if (messages.isEmpty) ...[
                _ChatBubble(
                  message: const MascotChatMessage(
                    role: 'assistant',
                    content:
                        'Bééé! Eu sou o Bode do Duolinfo. Pergunte como usar lições, XP, turmas, revisão espaçada ou pronúncia na plataforma!',
                  ),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: suggestions
                      .map(
                        (s) => ActionChip(
                          label: Text(
                            s,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: sending ? null : () => _submitText(s),
                        ),
                      )
                      .toList(),
                ),
              ] else ...[
                for (var i = 0; i < messages.length; i++) ...[
                  _ChatBubble(message: messages[i], isDark: isDark),
                  if (i < messages.length - 1) const SizedBox(height: 8),
                ],
              ],
              if (sending) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bode IA está pensando...',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('mascot-chat-input'),
                  controller: _inputCtrl,
                  enabled: !sending,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Pergunte sobre o Duolinfo...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _submitText(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                key: const Key('mascot-chat-send'),
                tooltip: 'Enviar',
                onPressed: sending ? null : () => _submitText(),
                icon: const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isDark});

  final MascotChatMessage message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final outOfScope = !isUser && !message.inScope;

    final bgColor = isUser
        ? colors.primary
        : (outOfScope
              ? (isDark ? const Color(0xFF3B2F14) : const Color(0xFFFFFBEB))
              : colors.surfaceContainerHigh);
    final fgColor = isUser
        ? colors.onPrimary
        : (outOfScope
              ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
              : colors.onSurface);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 270),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: outOfScope
              ? Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (outOfScope) ...[
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assistant_navigation,
                    size: 13,
                    color: Color(0xFFD97706),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Escopo do Duolinfo',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.content,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: fgColor),
            ),
            if (message.suggestedAction != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message.suggestedAction!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
