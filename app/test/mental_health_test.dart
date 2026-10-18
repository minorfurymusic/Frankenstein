import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/brain_ai.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/data/data_export.dart';
import 'package:frankstein/screens/health/health_tab.dart';
import 'package:frankstein/screens/health/mental_health_screen.dart';
import 'package:frankstein/screens/health/questionnaires.dart';
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

  testWidgets('PHQ-9 com o texto oficial: responde tudo, salva a pontuação, mostra o ponto de corte e não diagnostica',
      (tester) async {
    await pump(tester, MentalHealthScreen(deps: deps));
    await tester.tap(find.byKey(const Key('questionnaire_phq9')));
    await tester.pumpAndSettle();
    expect(find.text('1. Pouco interesse ou pouco prazer em fazer as coisas'), findsOneWidget);
    expect(find.textContaining('Não é necessária permissão para reproduzir'), findsOneWidget);
    // Sem todas as respostas, não salva.
    expect(tester.widget<FilledButton>(find.byKey(const Key('questionnaire_save'))).onPressed, isNull);
    for (var i = 0; i < 9; i++) {
      final key = Key('q_${i}_${i < 6 ? 2 : 0}');
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pump();
    }
    expect(find.byKey(const Key('crisis_notice')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('questionnaire_save')));
    await tester.tap(find.byKey(const Key('questionnaire_save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pontuação 12 de 27'), findsOneWidget);
    expect(find.textContaining('Isto não é diagnóstico'), findsOneWidget);
    expect(deps.healthRead.screenings('phq9').single.score, 12);
  });

  testWidgets('PHQ-9: qualquer resposta acima de "nenhuma vez" no item 9 mostra o aviso do CVV na hora', (tester) async {
    await pump(tester, QuestionnaireScreen(deps: deps, questionnaire: phq9));
    await tester.ensureVisible(find.byKey(const Key('q_8_1')));
    await tester.tap(find.byKey(const Key('q_8_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crisis_notice')), findsOneWidget);
  });

  test('GAD-7 tem 7 itens; os dois questionários usam o ponto de corte 10 dos autores', () {
    expect(gad7.items, hasLength(7));
    expect(gad7.items.first, 'Sentir-se nervoso(a), ansioso(a) ou muito tenso(a).');
    expect(scoreMessage(gad7, 10), contains('10 ou mais'));
    expect(scoreMessage(phq9, 4), contains('Abaixo de 10'));
  });

  test('aviso de procurar ajuda do Cérebro cita o CVV 188 e o SAMU 192 (texto do app)', () {
    expect(seekCareMessage, contains('188 (CVV'));
    expect(seekCareMessage, contains('192 (SAMU)'));
  });
}
