import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('shows the email and password login screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Entrar'), findsNWidgets(2));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('Cadastre-se'), findsOneWidget);
  });
}
