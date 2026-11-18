import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/audio/system_sound_service.dart';
import 'package:frontend/core/constants/brand_assets.dart';
import 'package:frontend/core/constants/supported_languages.dart';
import 'package:frontend/core/theme/admin_geral_theme.dart';
import 'package:frontend/core/ui/language_flag.dart';
import 'package:frontend/core/xp/xp_animation_controller.dart';
import 'package:frontend/core/xp/xp_level_progression.dart';
import 'package:frontend/features/dashboard/domain/entities/student_language_entity.dart';
import 'package:frontend/features/dashboard/presentation/widgets/animated_xp_avatar_ring.dart';
import 'package:frontend/features/dashboard/presentation/widgets/edit_profile_dialogs.dart';
import 'package:frontend/features/dashboard/presentation/widgets/language_progress_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SystemSoundService.resetForTest();
    XpAnimationController.resetForTest();
  });

  group('XpAnimationController & AnimatedXpAvatarRing', () {
    test('persists earned XP across reloads and consumes atomically', () async {
      await XpAnimationController.recordXpGain(25, source: 'Lição 1');
      await XpAnimationController.recordXpGain(15, source: 'Revisão');
      expect(XpAnimationController.pendingXp.value, 40);

      // Simulate returning after page reload
      XpAnimationController.resetForTest();
      await XpAnimationController.load();
      expect(XpAnimationController.pendingXp.value, 40);

      final consumed = await XpAnimationController.consumePendingXp();
      expect(consumed, 40);
      expect(XpAnimationController.pendingXp.value, 0);

      final secondConsume = await XpAnimationController.consumePendingXp();
      expect(secondConsume, 0);
    });

    testWidgets('animates scale, glow, and +XP badge when returning home', (
      tester,
    ) async {
      await XpAnimationController.recordXpGain(30, source: 'Quiz');

      var animating = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.blue,
            body: Center(
              child: AnimatedXpAvatarRing(
                name: 'Lucas Silva',
                pictureUrl: null,
                dailyXp: 50,
                dailyGoalXp: 100,
                forceAnimateInTest: true,
                onAnimatingChanged: (v) => animating = v,
              ),
            ),
          ),
        ),
      );

      // Let postFrameCallback and 260ms delay trigger consumeAndAnimate
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 500));

      expect(animating, isTrue);
      expect(find.text('+30 XP!'), findsOneWidget);
      expect(SystemSoundService.instance.lastPlayed, SystemSfxType.xpGain);

      // Complete 2400ms celebration cycle back to resting state
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();

      expect(animating, isFalse);
      expect(find.text('+30 XP!'), findsNothing);
      expect(find.text('50 / 100 XP hoje'), findsOneWidget);
    });
  });

  group('SystemSoundService', () {
    test('dispatches SFX and respects sound_effects_enabled mute toggle', () async {
      SystemSoundService.click();
      SystemSoundService.success();
      SystemSoundService.defeat();
      SystemSoundService.transition();
      SystemSoundService.notification();
      expect(SystemSoundService.instance.playCount, 5);
      expect(SystemSoundService.instance.lastPlayed, SystemSfxType.notification);

      await SystemSoundService.setEnabled(false);
      SystemSoundService.xpGain();
      expect(SystemSoundService.instance.playCount, 5);

      await SystemSoundService.load();
      expect(SystemSoundService.enabled.value, isFalse);
    });
  });

  group('LanguageFlag & BrandAssets & AdminGeralTheme', () {
    testWidgets('renders crisp vector flags and brand assets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const AppBrandBanner(),
                  const AppBrandIcon(),
                  for (final lang in kSupportedLanguages)
                    LanguageBadgePill(language: lang),
                  LanguageFlag.forLanguage('Português (Brasil)'),
                  AdminGoldGradientCard(
                    solidHero: true,
                    child: const Text('Painel Admin Geral'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LanguageFlag), findsNWidgets(kSupportedLanguages.length + 1));
      expect(find.text('Painel Admin Geral'), findsOneWidget);
      expect(AdminGeralTheme.goldMetallic, const Color(0xFFD4AF37));
      expect(BrandAssets.iconPath, 'assets/ICONE.jpg');
      expect(BrandAssets.bannerPath, 'assets/BANNER.jpg');
    });

    test('normalizes Google imgurl and formats errors cleanly', () {
      const wrapped =
          'https://www.google.com/imgres?imgurl=https%3A%2F%2Fexample.com%2Favatar.png&tbnid=123';
      expect(
        normalizeProfilePictureInputUrl(wrapped),
        'https://example.com/avatar.png',
      );
    });
  });

  group('XpLevelProgression & Difficulty Emojis', () {
    test('starts at 20 XP Lv 1 and scales by 1.5x per level', () {
      expect(XpLevelProgression.xpRequiredForLevel(1), 20);
      expect(XpLevelProgression.xpRequiredForLevel(2), 30);
      expect(XpLevelProgression.xpRequiredForLevel(3), 45);
      expect(XpLevelProgression.xpRequiredForLevel(4), 68);

      final lv1 = XpLevelProgression.fromXp(19);
      expect(lv1.level, 1);
      expect(lv1.currentLevelXp, 19);
      expect(lv1.xpRequiredForNextLevel, 20);

      final lv2 = XpLevelProgression.fromXp(20);
      expect(lv2.level, 2);
      expect(lv2.currentLevelXp, 0);
      expect(lv2.xpRequiredForNextLevel, 30);

      final lv3 = XpLevelProgression.fromXp(50);
      expect(lv3.level, 3);
      expect(lv3.currentLevelXp, 0);
      expect(lv3.xpRequiredForNextLevel, 45);
    });

    testWidgets('LanguageProgressCard and AnimatedXpAvatarRing show level progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AnimatedXpAvatarRing(
                  name: 'Maria',
                  pictureUrl: null,
                  dailyXp: 25,
                  dailyGoalXp: 50,
                  totalXp: 25,
                ),
                LanguageProgressCard(
                  language: StudentLanguageEntity(
                    id: 1,
                    languageName: 'Inglês',
                    level: 'Básico',
                    score: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nível 2 • 5/30 XP'), findsOneWidget);
      expect(find.text('Nv. 2 • Básico'), findsOneWidget);
      expect(find.text('Nível 2 • 0/30 XP'), findsOneWidget);
    });

    test('standardizes difficulty emojis across Fácil/Médio/Difícil and CEFR', () {
      expect(SupportedLanguages.levelEmoji('Fácil'), '🌱');
      expect(SupportedLanguages.levelEmoji('Médio'), '⚡');
      expect(SupportedLanguages.levelEmoji('Difícil'), '🚀');
      expect(SupportedLanguages.formatLevelWithEmoji('Fácil'), '🌱 Fácil');
      expect(SupportedLanguages.formatLevelWithEmoji('Médio'), '⚡ Médio');
      expect(SupportedLanguages.formatLevelWithEmoji('Difícil'), '🚀 Difícil');
    });
  });
}
