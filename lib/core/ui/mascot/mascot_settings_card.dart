import 'package:flutter/material.dart';

import 'interactive_mascot_stage.dart';
import 'mascot_assets.dart';
import 'mascot_preference_controller.dart';
import 'mascot_sprite_widget.dart';

/// Cartão reutilizável de personalização do mascote para todas as telas de
/// configurações (Aluno, Professor, Usuário e Administrador).
class MascotSettingsCard extends StatelessWidget {
  const MascotSettingsCard({
    super.key,
    this.accentColor = const Color(0xFF58CC02),
    this.cardColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(20),
  });

  final Color accentColor;
  final Color? cardColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final systemReduced =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Card(
      elevation: 0,
      color: cardColor ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color:
              borderColor ??
              theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: padding,
        child: ValueListenableBuilder<MascotVariant>(
          valueListenable: MascotPreferenceController.variant,
          builder: (context, selectedVariant, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: MascotPreferenceController.animationsEnabled,
              builder: (context, animEnabled, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: MascotPoseEmblem(
                            state: MascotState.idle,
                            size: 32,
                            glowColor: accentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mascote & Animações',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Escolha a versão do bode Duolinfo e controle o movimento das animações.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: MascotVariant.values.map((variant) {
                        final selected = variant == selectedVariant;
                        return ChoiceChip(
                          avatar: MascotPoseEmblem(
                            overrideVariant: variant,
                            size: 22,
                          ),
                          label: Text('${variant.label} • ${variant.description}'),
                          selected: selected,
                          selectedColor: accentColor.withValues(alpha: 0.2),
                          onSelected: (_) =>
                              MascotPreferenceController.setVariant(variant),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: accentColor,
                      title: const Text(
                        'Animar sprites e GIFs do mascote',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        systemReduced
                            ? 'Redução de movimento ativa no sistema — poses estáticas priorizadas automaticamente.'
                            : 'Quando desativado, exibe poses nítidas estáticas com menor consumo.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      value: animEnabled && !systemReduced,
                      onChanged: systemReduced
                          ? null
                          : (value) =>
                                MascotPreferenceController.setAnimationsEnabled(
                                  value,
                                ),
                    ),
                    const SizedBox(height: 10),
                    InteractiveMascotStage(
                      accentColor: accentColor,
                      mascotSize: 82,
                      height: 132,
                      showControls: true,
                      hintText:
                          'Teste toques, arraste direcional e reações de colisão aqui.',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => MascotCompanionModal.show(context),
                        icon: const Icon(Icons.auto_awesome_motion_rounded),
                        label: const Text('Abrir Estúdio (27 GIFs & Sprites)'),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
