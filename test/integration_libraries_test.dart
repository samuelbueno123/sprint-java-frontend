import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:velocity_x/velocity_x.dart';

void main() {
  testWidgets(
    'verify shadcn_ui, velocity_x and flutter_animate integrate cleanly',
    (tester) async {
      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: [
              const ShadBadge(child: Text('Test Badge')),
              ShadButton(onPressed: () {}, child: const Text('Test Button')),
            ].vStack().animate().fadeIn(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Badge'), findsOneWidget);
      expect(find.text('Test Button'), findsOneWidget);
    },
  );
}
