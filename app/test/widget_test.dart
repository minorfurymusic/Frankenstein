import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein_health_core/health_core.dart';

class _TestApp {
  final AppDependencies dependencies;
  final Widget widget;
  _TestApp(this.dependencies, this.widget);
}

_TestApp _buildTestApp() {
  final navigatorKey = GlobalKey<NavigatorState>();
  final dependencies = AppDependencies.inMemory(
    confirmationGate: AppConfirmationGate(navigatorKey),
  );
  final widget = FrankstitApp(dependencies: dependencies, navigatorKey: navigatorKey);
  return _TestApp(dependencies, widget);
}

void main() {
  testWidgets('app sobe na aba Resumo, com o dashboard carregado (zerado, sem eventos)',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bottom_nav')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_list')), findsOneWidget);
    expect(find.text('0'), findsOneWidget); // passos
  });

  testWidgets('alterna para a aba Chat pelo bottom nav', (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_input')), findsOneWidget);
  });

  testWidgets('comando de leitura reconhecido ("resumo de hoje") mostra resposta do get_daily_summary',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('chat_input')), 'resumo de hoje');
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('get_daily_summary'), findsOneWidget);
  });

  testWidgets('comando não reconhecido pelo roteador determinístico fica unresolved',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('chat_input')), 'oi, tudo bem?');
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não entendi'), findsOneWidget);
  });

  testWidgets('log_meal confirmado grava HealthEvent de verdade (comida real do catálogo TACO)',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    expect(app.dependencies.core.queryByType(HealthEventType.meal), isEmpty);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat_input')),
      'registrar refeição lunch: taco-1 150g',
    );
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();

    // Ferramenta de escrita — precisa aparecer o diálogo de confirmação
    // antes de qualquer coisa ser gravada (.claude/rules/brain.md, passo 4).
    expect(find.byKey(const Key('confirmation_confirm')), findsOneWidget);
    expect(app.dependencies.core.queryByType(HealthEventType.meal), isEmpty);

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('log_meal'), findsOneWidget);
    final mealEvents = app.dependencies.core.queryByType(HealthEventType.meal);
    expect(mealEvents, hasLength(1));
    expect(mealEvents.single.payload['meal_type'], 'lunch');
  });

  testWidgets('log_meal recusado no diálogo não grava nada', (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat_input')),
      'registrar refeição dinner: taco-1 100g',
    );
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmation_cancel')));
    await tester.pumpAndSettle();

    expect(find.textContaining('não registrei nada'), findsOneWidget);
    expect(app.dependencies.core.queryByType(HealthEventType.meal), isEmpty);
  });
}
