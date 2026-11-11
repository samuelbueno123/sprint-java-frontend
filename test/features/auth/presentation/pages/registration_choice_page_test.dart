import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/presentation/pages/registration_choice_page.dart';

void main() {
  testWidgets(
    'renders registration choice page with student and teacher options',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationChoicePage(
            initialEmail: 'novo@duolinfo.com',
            initialName: 'Novo Usuário',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Criar perfil'), findsOneWidget);
      expect(
        find.text('Escolha como você vai usar o Duolinfo.'),
        findsOneWidget,
      );
      expect(find.text('Sou estudante'), findsOneWidget);
      expect(
        find.text('Cadastre os idiomas que deseja estudar.'),
        findsOneWidget,
      );
      expect(find.text('Sou professor'), findsOneWidget);
      expect(
        find.text('Informe sua instituição e as áreas que leciona.'),
        findsOneWidget,
      );
      expect(find.text('Já tem perfil? Entrar'), findsOneWidget);
    },
  );
}
