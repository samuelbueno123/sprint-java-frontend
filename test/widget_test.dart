import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('shows student and teacher access options', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('ENTRAR COMO ALUNO'), findsOneWidget);
    expect(find.text('ENTRAR COMO PROFESSOR'), findsOneWidget);
  });
}
