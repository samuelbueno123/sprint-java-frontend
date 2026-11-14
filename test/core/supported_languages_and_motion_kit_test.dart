import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/supported_languages.dart';
import 'package:frontend/core/ui/motion_kit.dart';

void main() {
  group('SupportedLanguages domain consistency', () {
    test('contains strictly the 6 official base languages', () {
      expect(
        kSupportedLanguages,
        equals(<String>[
          'Alemão',
          'Espanhol',
          'Francês',
          'Inglês',
          'Italiano',
          'Japonês',
        ]),
      );
      expect(kSupportedLanguages.length, 6);
    });

    test('normalizes casing/accents and rejects unsupported languages', () {
      expect(SupportedLanguages.normalize('ingles'), 'Inglês');
      expect(SupportedLanguages.normalize('  FRANCÊS '), 'Francês');
      expect(SupportedLanguages.normalize('japones'), 'Japonês');
      expect(SupportedLanguages.normalize('alemao'), 'Alemão');

      expect(SupportedLanguages.normalize('Russo'), isNull);
      expect(SupportedLanguages.normalize('Coreano'), isNull);
      expect(SupportedLanguages.normalize('Mandarim'), isNull);
      expect(SupportedLanguages.isSupported('Português'), isFalse);

      expect(
        SupportedLanguages.normalizeOrDefault('Esperanto', 'Espanhol'),
        'Espanhol',
      );
      expect(SupportedLanguages.matches('frances', 'Francês'), isTrue);
      expect(SupportedLanguages.matches('Inglês', 'Italiano'), isFalse);
    });

    test('infers language from class name and sanitizes catalog lists', () {
      expect(
        SupportedLanguages.inferFromClassName('Turma Japonês N5'),
        'Japonês',
      );
      expect(
        SupportedLanguages.inferFromClassName('Conversação Alemão B1'),
        'Alemão',
      );
      expect(
        SupportedLanguages.inferFromClassName('Turma Geral'),
        kDefaultSupportedLanguage,
      );

      final sanitized = SupportedLanguages.sanitizeCatalogList([
        'Russo',
        'japones',
        'alemao',
        'Esperanto',
        'Inglês',
      ]);
      expect(sanitized, equals(['Alemão', 'Inglês', 'Japonês']));
    });

    test('provides valid short codes without emoji dependency', () {
      for (final lang in kSupportedLanguages) {
        final meta = SupportedLanguages.metaFor(lang);
        expect(meta.canonicalName, lang);
        expect(meta.shortCode.length, 2);
        expect(meta.nativeLabel, isNotEmpty);
      }
    });
  });

  group('MotionKit widgets & animations settle cleanly in tests', () {
    testWidgets(
      'MotionKit components and LanguageBadgePill render and settle',
      (tester) async {
        expect(isWidgetTestEnvironment, isTrue);
        var tapped = false;
        var tab = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    StaggeredReveal(
                      index: 0,
                      withScale: true,
                      child: InteractiveMotionCard(
                        onTap: () => tapped = true,
                        padding: const EdgeInsets.all(12),
                        child: const Column(
                          children: [
                            LanguageBadgePill(language: 'Japonês'),
                            AnimatedMetricCounter(value: 42, suffix: '%'),
                          ],
                        ),
                      ),
                    ),
                    const AnimatedLinearGauge(
                      percent: 0.72,
                      progressColor: Colors.teal,
                    ),
                    const AnimatedRadialGauge(
                      percent: 0.85,
                      color: Colors.indigo,
                      centerLabel: '85%',
                      subtitle: 'Saudável',
                    ),
                    const AppShimmerDashboardLoader(cardCount: 2),
                    StatefulBuilder(
                      builder: (context, setState) => Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              setState(() => tab = 1);
                              AppAnimatedFeedback.show(
                                context,
                                title: 'Sucesso',
                                message: 'Sincronizado',
                                tone: AppFeedbackTone.success,
                              );
                            },
                            child: const Text('Alternar'),
                          ),
                          MotionSectionSwitcher(
                            child: Text('Aba $tab', key: ValueKey(tab)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('JA'), findsOneWidget);
        expect(find.text('Japonês'), findsOneWidget);
        expect(find.text('42%'), findsOneWidget);
        expect(find.text('85%'), findsOneWidget);
        expect(find.text('Aba 0'), findsOneWidget);

        await tester.tap(find.text('Japonês'));
        expect(tapped, isTrue);

        await tester.tap(find.text('Alternar'));
        await tester.pumpAndSettle();
        expect(find.text('Aba 1'), findsOneWidget);
        expect(find.text('Sucesso'), findsOneWidget);
      },
    );

    testWidgets('MotionPageRoute transitions cleanly to next page', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MotionPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('Destino')),
                    ),
                  );
                },
                child: const Text('Navegar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Navegar'));
      await tester.pumpAndSettle();
      expect(find.text('Destino'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });
  });
}
