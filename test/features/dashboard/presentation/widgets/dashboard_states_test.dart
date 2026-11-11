import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/presentation/widgets/dashboard_empty_state.dart';
import 'package:frontend/features/dashboard/presentation/widgets/dashboard_error_state.dart';

void main() {
  group('DashboardErrorState', () {
    testWidgets('renders error message and triggers retry callback', (
      tester,
    ) async {
      var retryClicked = false;
      var loginClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardErrorState(
              message: 'Falha na conexão com o servidor.',
              onRetry: () => retryClicked = true,
              onBackToLogin: () => loginClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Atenção'), findsOneWidget);
      expect(find.text('Falha na conexão com o servidor.'), findsOneWidget);
      expect(find.text('Tentar Novamente'), findsOneWidget);
      expect(find.text('Ir para Login'), findsOneWidget);

      await tester.tap(find.text('Tentar Novamente'));
      await tester.pump();
      expect(retryClicked, isTrue);

      await tester.tap(find.text('Ir para Login'));
      await tester.pump();
      expect(loginClicked, isTrue);
    });

    testWidgets('omits login button when onBackToLogin is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardErrorState(
              message: 'Erro temporário.',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Ir para Login'), findsNothing);
      expect(find.text('Tentar Novamente'), findsOneWidget);
    });
  });

  group('DashboardEmptyState', () {
    testWidgets('renders title, message and triggers action button', (
      tester,
    ) async {
      var actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardEmptyState(
              icon: Icons.inbox_rounded,
              title: 'Nenhuma turma encontrada',
              message:
                  'Você ainda não foi alocado em nenhuma turma neste período letivo.',
              actionLabel: 'Ver turmas disponíveis',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('Nenhuma turma encontrada'), findsOneWidget);
      expect(
        find.text(
          'Você ainda não foi alocado em nenhuma turma neste período letivo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ver turmas disponíveis'), findsOneWidget);

      await tester.tap(find.text('Ver turmas disponíveis'));
      await tester.pump();
      expect(actionTriggered, isTrue);
    });
  });
}
