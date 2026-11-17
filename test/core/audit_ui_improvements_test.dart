import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/app_feedback_widgets.dart';
import 'package:frontend/core/constants/supported_languages.dart';
import 'package:frontend/core/theme/admin_geral_theme.dart';
import 'package:frontend/core/ui/language_flag.dart';

void main() {
  group('Audit UI Improvements Regression Tests', () {
    test('SupportedLanguages parses language+level and returns emojis', () {
      final parsed = SupportedLanguages.splitLanguageAndLevel('Inglês:Básico');
      expect(parsed.language, 'Inglês');
      expect(parsed.level, 'Básico');

      expect(SupportedLanguages.normalize('Inglês:Básico'), 'Inglês');
      expect(SupportedLanguages.levelEmoji('Básico'), '🌱');
      expect(SupportedLanguages.levelEmoji('Intermediário'), '⚡');
      expect(SupportedLanguages.levelEmoji('Avançado'), '🚀');
      expect(
        SupportedLanguages.formatLevelWithEmoji('Intermediário'),
        '⚡ Intermediário',
      );
      expect(SupportedLanguages.specializationEmoji('Conversação'), '🗣️');
      expect(SupportedLanguages.specializationEmoji('Negócios'), '💼');
    });

    testWidgets(
      'AdminGeralTheme applies gold contour on mobile and omits it on PC desktop',
      (tester) async {
        // Mobile viewport (< 600px) -> gold border enabled
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        late BoxDecoration mobileHero;
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            home: Builder(
              builder: (context) {
                expect(AdminGeralTheme.useGoldContour(context), isTrue);
                mobileHero = AdminGeralTheme.heroDecoration(context: context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(mobileHero.border, isNotNull);

        // PC viewport (>= 600px) -> gold border removed
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        late BoxDecoration pcHero;
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            home: Builder(
              builder: (context) {
                expect(AdminGeralTheme.useGoldContour(context), isFalse);
                pcHero = AdminGeralTheme.heroDecoration(context: context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(pcHero.border, isNull);
      },
    );

    testWidgets(
      'Feedback widgets render cleanly without goat visuals and flags cover 6 languages',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const AppLoader(message: 'Carregando...', compact: true),
                    const AppEmptyIllustration(icon: Icons.inbox_rounded),
                    const AppErrorIllustration(),
                    const AppInfoBanner(
                      title: 'Aviso',
                      message: 'Conteúdo informativo',
                    ),
                    for (final lang in kSupportedLanguages)
                      LanguageFlag.forLanguage(lang),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Carregando...'), findsOneWidget);
        expect(find.text('Aviso'), findsOneWidget);
        expect(
          find.byType(LanguageFlag),
          findsNWidgets(kSupportedLanguages.length),
        );
      },
    );
  });
}
