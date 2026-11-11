import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets('validates required email and invalid email format', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();

    final submitButton = find.widgetWithText(FilledButton, 'Entrar');
    expect(submitButton, findsOneWidget);

    // Tap submit with empty form
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Informe seu email.'), findsOneWidget);

    // Enter invalid email without @ and .
    final emailField = find.widgetWithText(TextFormField, 'Email');
    await tester.enterText(emailField, 'emailinvalido');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Informe um email válido.'), findsOneWidget);
  });

  testWidgets('toggles password visibility icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();

    final toggleButton = find.byTooltip('Mostrar senha');
    expect(toggleButton, findsOneWidget);

    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ocultar senha'), findsOneWidget);
  });
}
