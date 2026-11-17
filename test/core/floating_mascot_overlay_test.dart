import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/ui/mascot/mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OverlayChatAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final req = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      jsonEncode({
        'reply': 'Resposta do Bode IA para: ${req['message']}',
        'inScope': true,
        'suggestedAction': 'Abrir Lições',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MascotController.instance.resetForTest();
    await MascotPreferenceController.setVariant(MascotVariant.white);
    await MascotPreferenceController.setAnimationsEnabled(true);
  });

  tearDown(() {
    MascotController.instance.resetForTest();
  });

  group('FloatingMascotOverlay interactions & layout', () {
    testWidgets(
      'hides overlay when session is inactive and reveals when active',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Center(child: Text('Conteúdo base')),
                  FloatingMascotOverlay(),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const Key('floating-mascot-hit-target')),
          findsNothing,
        );

        MascotController.instance.setSessionActive(true);
        await tester.pump();
        expect(
          find.byKey(const Key('floating-mascot-hit-target')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'short tap opens popover, triggers click reaction, and submits AI chat',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 750));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
        dio.httpClientAdapter = _OverlayChatAdapter();
        MascotController.instance.setChatServiceForTest(
          MascotChatService(dio: dio),
        );
        MascotController.instance.setSessionActive(true);

        var underlyingPressed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ElevatedButton(
                        onPressed: () => underlyingPressed = true,
                        child: const Text('Botão Subjacente'),
                      ),
                    ),
                  ),
                  const FloatingMascotOverlay(),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        // Overlay must not block taps elsewhere on screen
        await tester.tap(find.text('Botão Subjacente'));
        await tester.pump();
        expect(underlyingPressed, isTrue);

        // Quick tap (< 200ms) opens popover & triggers clickPoke
        await tester.tap(find.byKey(const Key('floating-mascot-hit-target')));
        await tester.pumpAndSettle();

        expect(MascotController.instance.isChatOpen, isTrue);
        expect(MascotController.instance.activeState, MascotState.clickPoke);
        expect(
          find.byKey(const Key('floating-mascot-popover')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('mascot-chat-input')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('mascot-chat-input')),
          'Onde ficam meus gráficos?',
        );
        await tester.tap(find.byKey(const Key('mascot-chat-send')));
        await tester.pumpAndSettle();

        expect(
          find.text('Resposta do Bode IA para: Onde ficam meus gráficos?'),
          findsOneWidget,
        );
        expect(find.text('Abrir Lições'), findsOneWidget);
      },
    );

    testWidgets(
      'hold >= 200ms enters holdGrab and drag moves mascot without opening popover',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 750));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final controller = MascotController.instance;
        controller.setSessionActive(true);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Stack(children: [FloatingMascotOverlay()])),
          ),
        );
        await tester.pump();

        // Hold >= 200ms enters holdGrab without opening chat
        final target = find.byKey(const Key('floating-mascot-hit-target'));
        final gesture = await tester.startGesture(tester.getCenter(target));
        await tester.pump(const Duration(milliseconds: 250));
        expect(controller.isHeld, isTrue);
        expect(controller.activeState, MascotState.holdGrab);
        expect(controller.isChatOpen, isFalse);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.isHeld, isFalse);
        expect(controller.isChatOpen, isFalse);
        expect(find.byKey(const Key('floating-mascot-popover')), findsNothing);

        // Drag moves mascot without opening chat
        final startPos = controller.position;
        await tester.drag(target, const Offset(-160, -40));
        await tester.pumpAndSettle();
        expect(controller.position.dx, lessThan(startPos.dx - 100));
        expect(controller.isChatOpen, isFalse);
        expect(find.byKey(const Key('floating-mascot-popover')), findsNothing);
      },
    );

    testWidgets(
      'inside activity displays teacher help bubble or fallback instead of platform chat',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 750));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final controller = MascotController.instance;
        controller.setSessionActive(true);
        final token = controller.enterActivity(
          activityId: 'ex:12',
          title: 'Verbos Irregulares',
          mascotHelpMessage: 'Atenção à segunda coluna do verbo went.',
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Stack(children: [FloatingMascotOverlay()])),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('floating-mascot-hit-target')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('mascot-activity-help-text')),
          findsOneWidget,
        );
        expect(
          find.text('Atenção à segunda coluna do verbo went.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('mascot-chat-input')), findsNothing);

        controller.updateActivityContext(token, clearMascotHelpMessage: true);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('ainda não possui uma dica personalizada'),
          findsOneWidget,
        );

        controller.markActivityCompleted(token);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Atividade concluída — Modo Chama ativo!'),
          findsOneWidget,
        );
      },
    );

    testWidgets('clamps mascot coordinates inside shrinking viewport', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = MascotController.instance;
      controller.setSessionActive(true);
      controller.setPosition(const Offset(1060, 660));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Stack(children: [FloatingMascotOverlay()])),
        ),
      );
      await tester.pump();

      await tester.binding.setSurfaceSize(const Size(420, 520));
      await tester.pumpAndSettle();

      expect(controller.position.dx, lessThanOrEqualTo(420.0 - 112.0 - 8.0));
      expect(controller.position.dy, lessThanOrEqualTo(520.0 - 112.0 - 8.0));
    });
  });
}
