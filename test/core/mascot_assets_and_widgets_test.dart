import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/brand_assets.dart';
import 'package:frontend/core/ui/mascot/mascot.dart';
import 'package:frontend/core/ui/motion_kit.dart';
import 'package:frontend/features/access/presentation/pages/access_selection_page.dart';
import 'package:frontend/features/auth/presentation/pages/login_page.dart';
import 'package:frontend/features/auth/presentation/pages/registration_choice_page.dart';
import 'package:frontend/features/auth/presentation/widgets/registration_choice_dialog.dart';
import 'package:frontend/features/dashboard/presentation/widgets/dashboard_empty_state.dart';
import 'package:frontend/features/dashboard/presentation/widgets/dashboard_error_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MascotPreferenceController.setVariant(MascotVariant.white);
    await MascotPreferenceController.setAnimationsEnabled(true);
    MascotSpriteCache.instance.clearForTesting();
  });

  group('MascotAssets & MascotSpriteCache (duo_goat_spritesheet)', () {
    test(
      'all declared duo_goat_spritesheet assets load from AssetBundle',
      () async {
        final paths = MascotAssets.allDeclaredAssetPaths;
        expect(paths.length, 74);
        expect(paths.toSet().length, 74);

        for (final assetPath in paths) {
          expect(assetPath, startsWith('assets/duo_goat_spritesheet/'));
          final data = await rootBundle.load(assetPath);
          expect(
            data.lengthInBytes,
            greaterThan(0),
            reason: 'Asset $assetPath deveria ter bytes > 0',
          );
        }
      },
    );

    test(
      'all 23 MascotState enum values have complete specs and valid GIFs',
      () {
        expect(MascotAssets.specs.length, MascotState.values.length);
        expect(MascotAssets.specs.length, 23);
        expect(MascotAssets.specFor(MascotState.sad).loop, isFalse);
        expect(MascotAssets.specFor(MascotState.intense).loop, isFalse);
        expect(
          const MascotSprite(state: MascotState.idle).useSpriteSheet,
          isTrue,
        );
        for (final state in MascotState.values) {
          final spec = MascotAssets.specFor(state);
          expect(spec.frameCount, greaterThan(0));
          expect(spec.cols * spec.rows, greaterThanOrEqualTo(spec.frameCount));
          expect(spec.title, isNotEmpty);
          expect(spec.defaultQuote, isNotEmpty);
          expect(
            MascotAssets.gifFor(state, variant: MascotVariant.white),
            startsWith('assets/duo_goat_spritesheet/'),
          );
          expect(
            MascotAssets.sheetFor(state),
            startsWith('assets/duo_goat_spritesheet/'),
          );
          expect(MascotAssets.randomIdleQuote(1), isNotEmpty);
        }
      },
    );

    test('JSON catalogs & per-animation sheets load cleanly', () async {
      final cache = MascotSpriteCache.instance;

      final cat24Raw = await rootBundle.loadString(
        MascotAssets.catalog24FpsJson,
      );
      final catIntRaw = await rootBundle.loadString(
        MascotAssets.catalogInteractiveJson,
      );
      final cat24 = jsonDecode(cat24Raw) as List<dynamic>;
      final catInt = jsonDecode(catIntRaw) as List<dynamic>;

      expect(cat24.length, 4);
      expect(catInt.length, 19);

      final idleSheet = await cache.loadSpriteSheet(
        MascotAssets.specFor(MascotState.idle),
      );
      expect(idleSheet, isNotNull);
      expect(idleSheet!.frameCount, 24);

      final fireSheet = await cache.loadSpriteSheet(
        MascotAssets.specFor(MascotState.fireLoop),
      );
      expect(fireSheet, isNotNull);
      expect(fireSheet!.frameCount, 12);

      cache.clearForTesting();
    });
  });

  group('MascotPreferenceController', () {
    test('persists variant, targetFps, and animations toggle', () async {
      await MascotPreferenceController.setVariant(MascotVariant.fire);
      await MascotPreferenceController.setAnimationsEnabled(false);
      await MascotPreferenceController.setTargetFps(18);

      MascotPreferenceController.variant.value = MascotVariant.white;
      MascotPreferenceController.animationsEnabled.value = true;
      await MascotPreferenceController.load();

      expect(MascotPreferenceController.variant.value, MascotVariant.fire);
      expect(MascotPreferenceController.animationsEnabled.value, isFalse);
      expect(MascotPreferenceController.targetFps.value, 18);
    });

    testWidgets('shouldAnimate avoids infinite animation loops in tests', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final allowed = MascotPreferenceController.shouldAnimate(context);
              expect(allowed, isFalse);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('Mascot widgets & studio modal', () {
    testWidgets(
      'MascotSprite, MascotPoseEmblem, MascotGifBadge and loaders settle',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    MascotSprite(
                      state: MascotState.celebrate,
                      glowColor: Colors.amber,
                      onTap: () => tapped = true,
                    ),
                    const MascotSprite(
                      state: MascotState.intense,
                      maxFrames: 19,
                    ),
                    const MascotPoseEmblem(state: MascotState.intense),
                    const MascotGifBadge(state: MascotState.fireLoop),
                    const MascotLoader(
                      message: 'Carregando...',
                      showProgressBar: false,
                    ),
                    const MascotEmptyIllustration(state: MascotState.idle),
                    const MascotErrorIllustration(state: MascotState.sad),
                    const MascotSpeechBanner(
                      title: 'Bode Duo',
                      message: 'Bora estudar!',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(MascotSprite).first);
        await tester.pump();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'InteractiveMascotStage handles tap, drag, hold, and fire mode',
      (tester) async {
        final triggered = <MascotState>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InteractiveMascotStage(
                showControls: true,
                fireMode: true,
                onReaction: triggered.add,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Modo Chama Ativo'), findsOneWidget);

        await tester.tap(find.byType(MascotSprite).first);
        await tester.pumpAndSettle();
        expect(triggered, contains(MascotState.clickPoke));

        await tester.longPress(find.byType(MascotSprite).first);
        await tester.pumpAndSettle();
        expect(triggered, contains(MascotState.holdGrab));

        await tester.drag(
          find.byType(MascotSprite).first,
          const Offset(180, 0),
        );
        await tester.pumpAndSettle();
        expect(
          triggered.any(
            (s) =>
                s == MascotState.wallHitRight ||
                s == MascotState.dragStartRight ||
                s == MascotState.dragMoveRight,
          ),
          isTrue,
        );

        await tester.tap(find.text('Foco'));
        await tester.pumpAndSettle();
        expect(triggered, contains(MascotState.intense));

        await tester.tap(find.text('Comemorar'));
        await tester.pumpAndSettle();
        expect(triggered, contains(MascotState.celebrate));
      },
    );

    testWidgets('MascotSettingsCard opens 23-animation studio modal', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(960, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: MascotSettingsCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bode Duo Modo Chama'));
      await tester.pumpAndSettle();
      expect(MascotPreferenceController.variant.value, MascotVariant.fire);

      await tester.tap(find.text('Estúdio (23)'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Estúdio Interativo Duo Goat'),
        findsOneWidget,
      );
      expect(find.text('Colisões'), findsOneWidget);

      await tester.tap(find.text('Colisões'));
      await tester.pumpAndSettle();
      expect(
        find.text(MascotAssets.specFor(MascotState.wallHitRight).title),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets(
      'Auth screens display ICONE cleanly without banner or goat mascot',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 820));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(key: UniqueKey(), home: const AccessSelectionPage()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MascotSprite), findsNothing);
        expect(find.byType(AppBrandBanner), findsNothing);
        expect(find.byType(AppBrandIcon), findsOneWidget);
        expect(find.text('ENTRAR COMO ALUNO'), findsOneWidget);

        await tester.tap(find.text('ENTRAR COMO ALUNO'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(InteractiveMascotStage), findsNothing);
        expect(find.byType(AppBrandBanner), findsNothing);
        expect(find.byType(AppBrandIcon), findsOneWidget);

        // Mobile & compact viewports should also render only the brand icon.
        await tester.binding.setSurfaceSize(const Size(390, 844));
        await tester.pumpAndSettle();
        expect(find.byType(AppBrandBanner), findsNothing);
        expect(find.byType(AppBrandIcon), findsOneWidget);

        await tester.binding.setSurfaceSize(const Size(390, 620));
        await tester.pumpAndSettle();
        expect(find.byType(AppBrandBanner), findsNothing);
        expect(find.byType(AppBrandIcon), findsOneWidget);

        await tester.binding.setSurfaceSize(const Size(1280, 820));
        await tester.pumpWidget(
          MaterialApp(key: UniqueKey(), home: const RegistrationChoicePage()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppBrandBanner), findsNothing);
        expect(find.byType(AppBrandIcon), findsOneWidget);
        expect(find.text('Sou estudante'), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            home: const Scaffold(body: RegistrationChoiceDialog()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sou Estudante'), findsOneWidget);
      },
    );

    testWidgets(
      'EmptyState, ErrorState, and AppAnimatedFeedback render cleanly',
      (tester) async {
        var retried = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const DashboardEmptyState(
                      icon: Icons.inbox,
                      title: 'Sem dados',
                      message: 'Nada por aqui.',
                    ),
                    DashboardErrorState(
                      message: 'Falha momentânea',
                      onRetry: () => retried = true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Tentar Novamente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tentar Novamente'));
        expect(retried, isTrue);

        for (final tone in AppFeedbackTone.values) {
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return FilledButton(
                      onPressed: () => AppAnimatedFeedback.show(
                        context,
                        title: 'Feedback ${tone.name}',
                        message: 'Status ${tone.name}',
                        tone: tone,
                      ),
                      child: Text('Trigger ${tone.name}'),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.tap(find.text('Trigger ${tone.name}'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Feedback ${tone.name}'), findsOneWidget);
          expect(find.byType(MascotPoseEmblem), findsNothing);
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        }
      },
    );
  });
}
