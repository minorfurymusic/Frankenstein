import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frankstein/main.dart';

void main() {
  testWidgets('app sobe com uma tela em branco', (WidgetTester tester) async {
    await tester.pumpWidget(const FrankstitApp());

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text(''), findsNothing);
  });
}
