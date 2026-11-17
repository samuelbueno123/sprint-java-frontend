import 'package:flutter/material.dart';

import '../../audio/system_sound_service.dart';
import 'interactive_mascot_stage.dart';
import 'mascot_assets.dart';
import 'mascot_preference_controller.dart';
import 'mascot_sprite_widget.dart';

class MascotSettingsCard extends StatelessWidget {
  const MascotSettingsCard({
    super.key,
    this.accentColor = const Color(0xFF4F46E5),
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
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cardColor ?? colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor ?? colors.outlineVariant),
      ),
      child: Padding(
        padding: padding,
        child: ValueListenableBuilder<MascotVariant>(
          valueListenable: MascotPreferenceController.variant,
          builder: (context, currentVariant, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: MascotPreferenceController.animationsEnabled,
              builder: (context, animEnabled, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MascotPoseEmblem(
                          state: currentVariant == MascotVariant.fire
                              ? MascotState.fireLoop
                              : MascotState.clickHeart,
                          size: 52,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bode Duo — Mascote Interativo (23 Animações)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                MascotAssets.variantSubtitle(currentVariant),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            SystemSoundService.click();
                            MascotCompanionModal.show(context);
                          },
                          icon: const Icon(Icons.animation_rounded, size: 18),
                          label: const Text('Estúdio (23)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: MascotVariant.values.map((v) {
                        final selected = v == currentVariant;
                        return ChoiceChip(
                          avatar: MascotSprite(
                            state: v == MascotVariant.fire
                                ? MascotState.fireLoop
                                : MascotState.idle,
                            size: 24,
                            overrideVariant: v,
                          ),
                          label: Text(MascotAssets.variantName(v)),
                          selected: selected,
                          selectedColor: accentColor.withValues(alpha: 0.16),
                          onSelected: (_) {
                            SystemSoundService.pop();
                            MascotPreferenceController.setVariant(v);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Animações fluidas (24 FPS)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Ative ou pause os quadros animados do spritesheet Duo Goat',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: animEnabled,
                      activeThumbColor: accentColor,
                      onChanged: (val) {
                        SystemSoundService.click();
                        MascotPreferenceController.setAnimationsEnabled(val);
                      },
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
