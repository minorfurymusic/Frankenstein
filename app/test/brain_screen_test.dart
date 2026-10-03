import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein_health_core/health_core.dart';

import 'support/fonts.dart';

void main() {
  setUpAll(loadFigtree);

  late AppDependencies deps;
  late AppConfirmationGate gate;
  late Widget app;

  setUp(() {
    final navigatorKey = GlobalKey<NavigatorState>();
    gate = AppConfirmationGate(navigatorKey);
    deps = AppDependencies.inMemory(confirmationGate: gate, shareSheet: FakeShareSheet(), imageCapturer: FakeCardImageCapturer());
    app = FrankstitApp(dependencies: deps, navigatorKey: navigatorKey);
  });
  tearDown(() => deps.close());

  Future<void> openBrain(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav_cerebro')));
    await tester.pumpAndSettle();
  }

  testWidgets('modo básico avisa e mostra exemplos; o Cérebro passa a apresentar as confirmações', (tester) async {
    await openBrain(tester);
    expect(find.byKey(const Key('brain_basic_notice')), findsOneWidget);
    expect(find.text('registrar água 500ml'), findsOneWidget);
    expect(gate.presenter, isNotNull);
  });

  testWidgets('exemplo "registrar água 500ml" vira cartão; nada grava até confirmar', (tester) async {
    await openBrain(tester);
    await tester.tap(find.byKey(const Key('brain_example_registrar água 500ml')));
    await tester.pumpAndSettle();

    expect(find.text('Água — 500 ml'), findsOneWidget);
    expect(find.text('ÁGUA'), findsOneWidget);
    expect(deps.core.queryByType(HealthEventType.water), isEmpty);

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.water).single.payload['amount_ml'], 500);
    expect(find.text('Salvo em Nutrição › Água'), findsOneWidget);
  });

  testWidgets('refeição em português ("almoço") também é entendida no modo básico', (tester) async {
    await openBrain(tester);
    await tester.enterText(find.byKey(const Key('chat_input')), 'registrar refeição almoço: taco-1 100g');
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.meal).single.payload['meal_type'], 'lunch');
  });

  testWidgets('nova conversa limpa as mensagens e descarta cartão pendente sem gravar', (tester) async {
    await openBrain(tester);
    await tester.tap(find.byKey(const Key('brain_example_registrar água 500ml')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brain_new')));
    await tester.pumpAndSettle();
    expect(find.text('O que você quer registrar?'), findsOneWidget);
    expect(deps.core.queryByType(HealthEventType.water), isEmpty);
  });
}
