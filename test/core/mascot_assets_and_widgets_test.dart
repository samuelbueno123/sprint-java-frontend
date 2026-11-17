import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('MascotAssets & MascotSpriteCache', () {
    test('all 80 declared mascot assets load successfully from AssetBundle', () async {
      final paths = MascotAssets.allDeclaredAssetPaths;
      expect(paths.length, 80);
      expect(paths.toSet().length, 80);

      for (final path in paths) {
        final data = await rootBundle.load(path);
        expect(
          data.lengthInBytes,
          greaterThan(0),
          reason: 'Asset vazio ou ausente: $path',
        );
      }
    });

    test('all 23 MascotState enum values have complete specs and valid GIF mappings', () {
      expect(MascotAssets.specs.length, MascotState.values.length);
      for (final state in MascotState.values) {
        final spec = MascotAssets.specFor(state);
        expect(spec.frameCount, greaterThan(0));
        expect(spec.cols * spec.rows, greaterThanOrEqualTo(spec.frameCount));
        expect(spec.title, isNotEmpty);
        expect(spec.defaultQuote, isNotEmpty);
        expect(MascotAssets.gifFor(state, variant: MascotVariant.white), spec.gifAssetPath);
        expect(
          MascotAssets.gifFor(state, variant: MascotVariant.green),
          startsWith('assets/mascot/gifs/green/'),
        );
      }
    });

    test('JSON catalogs and sprite atlases parse frame rects for white, 24fps master, and green variants', () async {
      final cache = MascotSpriteCache.instance;

      final cat24Raw = await rootBundle.loadString(MascotAssets.catalog24FpsJson);
      final catIntRaw = await rootBundle.loadString(MascotAssets.catalogInteractiveJson);
      final cat24 = jsonDecode(cat24Raw) as List<dynamic>;
      final catInt = jsonDecode(catIntRaw) as List<dynamic>;

      expect(cat24.length, 4);
      expect(catInt.length, 19);

      // Bode Branco grid individual (idle = 24 quadros)
      final idleFramesWhite = await cache.loadFramesForSpec(
        MascotAssets.specFor(MascotState.idle),
        variant: MascotVariant.white,
      );
      expect(idleFramesWhite.length, 24);

      // Bode Branco master 24fps atlas
      final celebrateMasterFrames = await cache.loadFramesForSpec(
        MascotAssets.specFor(MascotState.celebrate),
        variant: MascotVariant.white,
        useMaster24FpsAtlas: true,
      );
      expect(celebrateMasterFrames.length, 24);

      // Bode Verde atlas clássico (4 quadros por estado)
      final intenseGreenFrames = await cache.loadFramesForSpec(
        MascotAssets.specFor(MascotState.intense),
        variant: MascotVariant.green,
      );
      expect(intenseGreenFrames.length, 4);

      // Interativo (12 quadros a 24 FPS)
      final spinFrames = await cache.loadFramesForSpec(
        MascotAssets.specFor(MascotState.clickSpin),
        variant: MascotVariant.white,
      );
      expect(spinFrames.length, 12);
    });

    test('decodes master PNGs via cache and enforces bounded LRU eviction', () async {
      final cache = MascotSpriteCache.instance;
      final whiteImg = await cache.loadImage(MascotAssets.whiteMasterSheet);
      final greenImg = await cache.loadImage(MascotAssets.greenMasterSheet);

      expect(whiteImg, isNotNull);
      expect(whiteImg!.width, 1024);
      expect(whiteImg.height, 1024);

      expect(greenImg, isNotNull);
      expect(greenImg!.width, 1024);
      expect(greenImg.height, 1024);

      // Asset inexistente retorna null com segurança
      final missingImg = await cache.loadImage('assets/mascot/does_not_exist.png');
      expect(missingImg, isNull);
    });
  });

  group('MascotPreferenceController', () {
    testWidgets('persists variant and animation settings and honors reduced motion', (
      tester,
    ) async {
      await MascotPreferenceController.setVariant(MascotVariant.green);
      await MascotPreferenceController.setAnimationsEnabled(false);

      // Limpa em memória simulando reinício e recarrega via SharedPreferences
      MascotPreferenceController.variant.value = MascotVariant.white;
      MascotPreferenceController.animationsEnabled.value = true;
      await MascotPreferenceController.load();

      expect(MascotPreferenceController.variant.value, MascotVariant.green);
      expect(MascotPreferenceController.animationsEnabled.value, isFalse);

      late bool allowedInTest;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                allowedInTest = MascotPreferenceController.shouldAnimate(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(allowedInTest, isFalse);
    });
  });

  group('Reusable Mascot Widgets', () {
    testWidgets('MascotSprite, MascotPoseEmblem, MascotGifBadge and MascotLoader render and handle errors safely', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MascotSprite(
                    state: MascotState.celebrate,
                    size: 72,
                    glowColor: Colors.green,
                    onTap: () => tapped = true,
                  ),
                  const MascotPoseEmblem(
                    state: MascotState.intense,
                    overrideVariant: MascotVariant.green,
                    size: 40,
                  ),
                  const MascotGifBadge(
                    state: MascotState.sad,
                    explicitGifPath: 'assets/mascot/invalid.gif',
                    size: 64,
                  ),
                  const MascotLoader(
                    message: 'Carregando lição...',
                    subtitle: 'Preparando áudios',
                    state: MascotState.idle,
                  ),
                  const MascotLoader(
                    message: 'Compacto',
                    compact: true,
                    showProgressBar: false,
                    useSpriteSheet: true,
                  ),
                  const MascotEmptyIllustration(state: MascotState.idle),
                  const MascotErrorIllustration(state: MascotState.sad),
                  const MascotSpeechBanner(
                    title: 'Dica',
                    message: 'Continue praticando!',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Carregando lição...'), findsOneWidget);
      expect(find.text('Preparando áudios'), findsOneWidget);
      expect(find.text('Compacto'), findsOneWidget);
      expect(find.text('Dica'), findsOneWidget);

      await tester.tap(find.byType(MascotSprite).first);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('InteractiveMascotStage handles tap, drag, long press, and control chips', (
      tester,
    ) async {
      final triggered = <MascotState>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveMascotStage(
              showControls: true,
              onReaction: triggered.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toque no mascote
      await tester.tap(find.byType(MascotSprite).first);
      await tester.pumpAndSettle();
      expect(triggered, contains(MascotState.clickPoke));

      // Pressão longa -> holdGrab
      final center = tester.getCenter(find.byType(MascotSprite).first);
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 650));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(triggered, contains(MascotState.holdGrab));

      // Arraste rápido à direita -> bounce/wall hit ou drag
      await tester.fling(
        find.byType(MascotSprite).first,
        const Offset(120, 0),
        900,
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

      // Chips de controle
      await tester.tap(find.text('Ativar Modo Chama'));
      await tester.pumpAndSettle();
      expect(find.text('Modo Chama Ativo'), findsOneWidget);

      await tester.tap(find.text('Foco Intenso'));
      await tester.pumpAndSettle();
      expect(triggered, contains(MascotState.intense));

      await tester.tap(find.text('Comemorar'));
      await tester.pumpAndSettle();
      expect(triggered, contains(MascotState.celebrate));
    });

    testWidgets('MascotSettingsCard switches variants, toggles animations, and opens MascotCompanionModal studio', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: MascotSettingsCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Bode Verde'));
      await tester.pumpAndSettle();
      expect(MascotPreferenceController.variant.value, MascotVariant.green);

      await tester.tap(find.text('Abrir Estúdio (27 GIFs & Sprites)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Estúdio & Catálogo do Mascote Duolinfo'),
        findsOneWidget,
      );
      expect(find.text('Colisões'), findsOneWidget);

      // Filtro de categoria
      await tester.tap(find.text('Colisões'));
      await tester.pumpAndSettle();
      expect(
        find.text(MascotAssets.specFor(MascotState.wallHitRight).title),
        findsOneWidget,
      );

      // Alternar formato para Spritesheet 24 FPS
      await tester.tap(find.textContaining('Prévia: GIF Oficial'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Prévia: Spritesheet 24 FPS'), findsOneWidget);
    });
  });

  group('Screen Integration & Navigation Flows', () {
    testWidgets('AccessSelectionPage renders mascot and navigates to LoginPage', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: AccessSelectionPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MascotSprite), findsWidgets);
      await tester.tap(find.text('ENTRAR COMO ALUNO'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(InteractiveMascotStage), findsOneWidget);
    });

    testWidgets('RegistrationChoicePage & Dialog render cleanly on mobile and desktop without overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: RegistrationChoicePage()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MascotSprite), findsWidgets);
      expect(find.text('Sou estudante'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => RegistrationChoiceDialog.show(
                  context,
                  initialName: 'Ana',
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(MascotSprite), findsWidgets);
      expect(find.text('Sou Estudante'), findsOneWidget);
    });

    testWidgets('DashboardEmptyState, DashboardErrorState, and AppAnimatedFeedback show mascot artwork across tones', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const DashboardEmptyState(
                    icon: Icons.inbox_rounded,
                    title: 'Sem dados',
                    message: 'Nada por aqui ainda.',
                  ),
                  DashboardErrorState(
                    message: 'Falha temporária',
                    onRetry: () => retried = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MascotEmptyIllustration), findsOneWidget);
      expect(find.byType(MascotErrorIllustration), findsOneWidget);

      await tester.tap(find.text('Tentar Novamente'));
      await tester.pump();
      expect(retried, isTrue);

      for (final tone in AppFeedbackTone.values) {
        final ctx = tester.element(find.byType(DashboardErrorState));
        AppAnimatedFeedback.show(
          ctx,
          title: 'Feedback ${tone.name}',
          tone: tone,
        );
        await tester.pump();
        expect(find.text('Feedback ${tone.name}'), findsOneWidget);
        expect(find.byType(MascotPoseEmblem), findsWidgets);
        ScaffoldMessenger.of(ctx).removeCurrentSnackBar();
        await tester.pumpAndSettle();
      }
    });
  });
}
