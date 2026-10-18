import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/brain_ai.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/data/data_export.dart';
import 'package:frankstein/screens/health/health_tab.dart';
import 'package:frankstein/screens/health/mental_health_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_health_core/health_core.dart';

import 'support/fonts.dart';

void main() {
  setUpAll(loadFigtree);

  late AppDependencies deps;
  setUp(() {
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
    );
  });
  tearDown(() => deps.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: Scaffold(body: home)));
    await tester.pumpAndSettle();
  }

  testWidgets('humor em um toque: escolhe o rosto, completa se quiser e salva no celular', (tester) async {
    await pump(tester, MentalHealthScreen(deps: deps));
    expect(find.byKey(const Key('crisis_notice')), findsOneWidget);
    expect(find.textContaining('188 (CVV'), findsOneWidget);
    expect(find.textContaining('Nenhum registro ainda'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mood_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mood_energy_1')));
    await tester.tap(find.byKey(const Key('mood_anxiety_4')));
    await tester.tap(find.byKey(const Key('mood_feeling_triste')));
    await tester.enterText(find.byKey(const Key('mood_notes')), 'briguei no trabalho');
    await tester.tap(find.byKey(const Key('mood_save')));
    await tester.pumpAndSettle();

    final e = deps.core.queryByType(HealthEventType.mood).single;
    expect(e.payload['mood'], 2);
    expect(e.payload['energy'], 1);
    expect(e.payload['anxiety'], 4);
    expect(e.payload['feelings'], ['triste']);
    expect(e.source, HealthEventSource.manual);
    expect(find.byKey(const Key('mood_strip')), findsOneWidget);
    expect(find.textContaining('Hoje: Mal'), findsOneWidget);
    expect(find.textContaining('energia 1/5 · ansiedade 4/5 · triste'), findsOneWidget);

    // Entra na exportação completa, como todo dado da pessoa.
    final export = buildFullExport(deps);
    expect((export['events'] as List).where((x) => (x as Map)['type'] == 'mood'), hasLength(1));
  });

  testWidgets('sintoma mental usa o diário de sintomas com atalhos próprios', (tester) async {
    await pump(tester, MentalHealthScreen(deps: deps));
    await tester.tap(find.byKey(const Key('mental_symptom')));
    await tester.pumpAndSettle();
    expect(find.text('Crise de ansiedade'), findsOneWidget);
    await tester.tap(find.text('Insônia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('symptom_save')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.symptom).single.payload['name'], 'Insônia');
  });

  testWidgets('aba Saúde tem a seção Saúde mental com o último humor', (tester) async {
    final now = DateTime.now();
    deps.moodLogger.log(mood: 4, occurredAt: now.toUtc(), occurredAtTzOffsetMinutes: now.timeZoneOffset.inMinutes);
    await pump(tester, HealthTab(deps: deps));
    expect(find.text('Último humor: Bem'), findsOneWidget);
  });

  test('aviso de procurar ajuda do Cérebro cita o CVV 188 e o SAMU 192 (texto do app)', () {
    expect(seekCareMessage, contains('188 (CVV'));
    expect(seekCareMessage, contains('192 (SAMU)'));
  });
}
