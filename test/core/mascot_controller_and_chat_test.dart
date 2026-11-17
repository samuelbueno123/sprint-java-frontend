import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/ui/mascot/mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockChatAdapter implements HttpClientAdapter {
  _MockChatAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
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

  group('MascotController state machine & activity stack', () {
    test('click reactions cycle in deterministic order', () {
      final controller = MascotController.instance;
      final visited = <MascotState>[];
      for (var i = 0; i < 6; i++) {
        controller.triggerClickReaction();
        visited.add(controller.activeState);
        controller.onOneShotFinished();
      }
      expect(visited, const [
        MascotState.clickPoke,
        MascotState.clickBleat,
        MascotState.clickShake,
        MascotState.clickSpin,
        MascotState.clickHeart,
        MascotState.clickPoke,
      ]);
      expect(controller.activeState, MascotState.idle);
    });

    test(
      'nested token activity stack preserves and restores outer context',
      () {
        final controller = MascotController.instance;
        expect(controller.isInActivity, isFalse);

        final outer = controller.enterActivity(
          activityId: 'path:1',
          title: 'Módulo 1',
          mascotHelpMessage: 'Revise o vocabulário base.',
        );
        expect(controller.isInActivity, isTrue);
        expect(controller.currentActivity?.title, 'Módulo 1');
        expect(
          controller.currentActivity?.mascotHelpMessage,
          'Revise o vocabulário base.',
        );

        final inner = controller.enterActivity(
          activityId: 'diag:2',
          title: 'Nivelamento',
        );
        expect(controller.currentActivity?.title, 'Nivelamento');
        expect(controller.currentActivity?.mascotHelpMessage, isNull);

        controller.updateActivityContext(
          inner,
          mascotHelpMessage: 'Dica atualizada do diagnóstico.',
        );
        expect(
          controller.currentActivity?.mascotHelpMessage,
          'Dica atualizada do diagnóstico.',
        );

        controller.exitActivity(inner);
        expect(controller.isInActivity, isTrue);
        expect(controller.currentActivity?.title, 'Módulo 1');
        expect(
          controller.currentActivity?.mascotHelpMessage,
          'Revise o vocabulário base.',
        );

        controller.updateActivityContext(outer, isCompleted: false);
        expect(
          controller.currentActivity?.mascotHelpMessage,
          'Revise o vocabulário base.',
        );
        controller.updateActivityContext(outer, clearMascotHelpMessage: true);
        expect(controller.currentActivity?.mascotHelpMessage, isNull);

        controller.exitActivity(outer);
        expect(controller.isInActivity, isFalse);
        expect(controller.currentActivity, isNull);
      },
    );

    test(
      'reactCorrect and reactIncorrect settle to resting state unless held',
      () {
        final controller = MascotController.instance;

        controller.reactCorrect();
        expect(controller.activeState, MascotState.celebrate);
        controller.onOneShotFinished();
        expect(controller.activeState, MascotState.idle);

        controller.reactIncorrect();
        expect(controller.activeState, MascotState.sad);
        controller.onOneShotFinished();
        expect(controller.activeState, MascotState.idle);

        controller.beginHold();
        expect(controller.activeState, MascotState.holdGrab);
        controller.reactCorrect();
        expect(controller.activeState, MascotState.holdGrab);
        controller.endHoldOrDrag();
        expect(controller.activeState, MascotState.idle);
      },
    );

    test(
      'markActivityCompleted ignites 19-frame eye-fire then transitions to fireLoop',
      () {
        final controller = MascotController.instance;
        final token = controller.enterActivity(
          activityId: 'ex:99',
          title: 'Quiz Final',
        );

        controller.markActivityCompleted(token);
        expect(controller.isActivityCompleted, isTrue);
        expect(controller.activeState, MascotState.intense);
        expect(controller.maxFramesOverride, 19);

        controller.onOneShotFinished();
        expect(controller.activeState, MascotState.fireLoop);
        expect(controller.maxFramesOverride, isNull);
        expect(controller.restingState, MascotState.fireLoop);

        // Resetting completion (e.g. next card/challenge) clears fire state
        controller.updateActivityContext(token, isCompleted: false);
        expect(controller.isActivityCompleted, isFalse);
        expect(controller.activeState, MascotState.idle);

        controller.exitActivity(token);
        expect(controller.activeState, MascotState.idle);
      },
    );
  });

  group('MascotChatService & platform chat integration', () {
    test(
      'sends context payload and parses in-scope and out-of-scope replies',
      () async {
        final requests = <Map<String, dynamic>>[];
        var callCount = 0;

        final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
        dio.httpClientAdapter = _MockChatAdapter((options) async {
          expect(options.method, 'POST');
          expect(options.path, '/api/ai/mascot/chat');
          requests.add(Map<String, dynamic>.from(options.data as Map));
          callCount++;

          final responsePayload = callCount == 1
              ? {
                  'reply': 'Complete lições na aba Início para acumular XP!',
                  'inScope': true,
                  'suggestedAction': 'Ir para Lições',
                }
              : {
                  'reply':
                      'Só posso ajudar com navegação e recursos do Duolinfo!',
                  'inScope': false,
                  'suggestedAction': 'Explorar Trilha',
                };

          return ResponseBody.fromString(
            jsonEncode(responsePayload),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final service = MascotChatService(dio: dio);
        final controller = MascotController.instance;
        controller.setChatServiceForTest(service);
        controller.updateNavigationContext(
          section: 'srsReview',
          userRole: 'student',
          languageCode: 'Francês',
        );

        await controller.sendChatMessage('Como ganho mais XP?');
        expect(controller.chatMessages.length, 2);
        expect(controller.chatMessages.first.isUser, isTrue);
        expect(controller.chatMessages.last.inScope, isTrue);
        expect(controller.chatMessages.last.suggestedAction, 'Ir para Lições');
        expect(requests.last['activeSection'], 'srsReview');
        expect(requests.last['userRole'], 'student');
        expect(requests.last['currentLanguage'], 'Francês');
        expect(requests.last['history'], isEmpty);

        await controller.sendChatMessage('Qual a receita de bolo?');
        expect(controller.chatMessages.length, 4);
        expect(controller.chatMessages.last.inScope, isFalse);
        expect(controller.chatMessages.last.suggestedAction, 'Explorar Trilha');
        final history = requests.last['history'] as List;
        expect(history.length, 2);
        expect(history.first['role'], 'user');
      },
    );
  });
}
