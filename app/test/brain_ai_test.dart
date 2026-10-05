import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/ai/brain_ai.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/screens/brain/brain_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';

import 'support/fonts.dart';

class FakeTransport implements AiTransport {
  final List<Object> replies = [];
  final List<String> bodies = [];
  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    bodies.add(body);
    return AiHttpResponse(200, jsonEncode({
      'candidates': [
        {'content': {'parts': [{'text': jsonEncode(replies.removeAt(0))}]}},
      ],
    }));
  }
}

final losartana = Medication(
  id: 'm1',
  name: 'Losartana',
  doseAmount: 50,
  doseUnit: 'mg',
  form: MedicationForm.tablet,
  timesOfDay: const [8 * 60],
  startDate: LocalDate(2026, 1, 1),
);

void main() {
  setUpAll(loadFigtree);

  late FakeTransport transport;
  late MemorySecretStore secrets;
  late GlobalKey<NavigatorState> nav;
  late AppDependencies deps;

  setUp(() {
    transport = FakeTransport();
    secrets = MemorySecretStore();
    nav = GlobalKey<NavigatorState>();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(nav),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      secretStore: secrets,
      aiTransport: transport,
    );
  });
  tearDown(() => deps.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, theme: RltTheme.light(), home: Scaffold(body: BrainScreen(deps: deps))));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('chat_input')), text);
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();
  }

  testWidgets('uma frase vira vários cartões; cada um é decidido sozinho; só o texto vai à IA', (tester) async {
    secrets.values['gemini_api_key'] = 'CHAVE';
    await deps.ai.load();
    deps.medicationRepository.save(losartana);
    transport.replies.add({
      'reply': 'Anotei.',
      'water': [
        {'amount_ml': 2000},
      ],
      'meals': [
        {
          'meal_type': 'breakfast',
          'items': [
            {'name': 'Ovo cozido', 'grams': 150, 'kcal': 210, 'protein_g': 19, 'carbs_g': 1.5, 'fat_g': 14},
          ],
        },
      ],
      'medication_doses': [
        {'name': 'Dipirona', 'status': 'taken', 'at': '2026-10-05T09:00:00-03:00'},
        {'name': 'losartana', 'status': 'taken'},
      ],
      'questions': ['steps'],
    });
    await pump(tester);
    expect(find.byKey(const Key('brain_ai_notice')), findsOneWidget);

    await send(tester, 'bebi 2 L de água, comi 3 ovos, tomei dipirona às 9h e a losartana');
    expect(find.byKey(const Key('ai_consent')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_consent_yes')));
    await tester.pumpAndSettle();

    // Só a mensagem e a hora; a lista de remédios cadastrados não sai do aparelho.
    expect(transport.bodies, hasLength(1));
    expect(transport.bodies.single, contains('tomei dipirona'));
    expect(transport.bodies.single, isNot(contains('m1')));
    expect(find.byKey(const Key('brain_ai_disclaimer')), findsWidgets);
    // Dipirona sem dose e sem cadastro: pergunta em vez de inventar dose.
    expect(find.textContaining('Para registrar Dipirona, me diga a dose'), findsOneWidget);
    // Pergunta sobre os próprios dados: respondida aqui, na hora.
    expect(find.text('Hoje: 0 passos.'), findsOneWidget);

    expect(find.text('Água — 2.000 ml'), findsOneWidget);
    expect(find.text('Café da manhã — Ovo cozido 150 g'), findsOneWidget);
    expect(find.text('≈ 210 kcal (estimativa)'), findsOneWidget);
    expect(find.byKey(const Key('proposal_estimate')), findsOneWidget);
    expect(find.text('Remédio tomado — Losartana'), findsOneWidget);
    expect(find.byKey(const Key('confirmation_confirm')), findsNWidgets(3));
    expect(deps.core.queryByType(HealthEventType.water), isEmpty);

    // Ajusta a estimativa: 150 g → 100 g, as calorias acompanham.
    await tester.tap(find.byTooltip('Editar Café da manhã — Ovo cozido 150 g'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('proposal_grams_0')), '100');
    await tester.tap(find.byKey(const Key('confirmation_confirm')).at(1));
    await tester.pumpAndSettle();
    final meal = deps.core.queryByType(HealthEventType.meal).single;
    expect((meal.payload['totals'] as Map)['energy_kcal'], closeTo(140, 0.5));
    expect(deps.nutrition.myItems(), isEmpty);

    // Água confirmada, remédio descartado — independentes.
    await tester.tap(find.byKey(const Key('confirmation_confirm')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmation_cancel')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.water).single.payload['amount_ml'], 2000);
    expect(deps.core.queryByType(HealthEventType.medicationDose), isEmpty);

    // Comando exato continua no roteador, sem rede.
    await send(tester, 'registrar água 300ml');
    expect(transport.bodies, hasLength(1));
    expect(find.text('Água — 300 ml'), findsOneWidget);
  });

  testWidgets('sinal de alerta: o app mostra o aviso dele de procurar atendimento', (tester) async {
    secrets.values['gemini_api_key'] = 'CHAVE';
    await deps.ai.load();
    deps.ai.giveConsent();
    transport.replies.add({
      'reply': 'Anotei o sintoma.',
      'seek_care': true,
      'symptoms': [
        {'name': 'Dor no peito', 'intensity': 8},
      ],
    });
    await pump(tester);
    await send(tester, 'estou com uma dor forte no peito');
    expect(find.text(seekCareMessage), findsOneWidget);
    expect(find.text('Sintoma — Dor no peito'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.symptom).single.payload['name'], 'Dor no peito');
  });

  testWidgets('sem chave: texto livre não sai do aparelho; "Não agora" no consentimento também não', (tester) async {
    await pump(tester);
    await send(tester, 'comi 2 ovos');
    expect(transport.bodies, isEmpty);
    expect(find.textContaining('Não entendi'), findsOneWidget);

    secrets.values['gemini_api_key'] = 'CHAVE';
    await deps.ai.load();
    await tester.pumpAndSettle();
    await send(tester, 'comi 2 ovos');
    await tester.tap(find.byKey(const Key('ai_consent_no')));
    await tester.pumpAndSettle();
    expect(transport.bodies, isEmpty);
    expect(find.text('Ok, não enviei nada.'), findsOneWidget);
  });

  test('remédio casado no aparelho: nome igual ou começo do nome, sem acento', () {
    final dipirona = Medication(
      id: 'm2',
      name: 'Dipirona sódica',
      doseAmount: 500,
      doseUnit: 'mg',
      form: MedicationForm.tablet,
      timesOfDay: const [8 * 60],
      startDate: LocalDate(2026, 1, 1),
    );
    final meds = [losartana, dipirona];
    expect(matchMedication(meds, 'LOSARTANA')?.id, 'm1');
    expect(matchMedication(meds, 'dipirona')?.id, 'm2');
    expect(matchMedication(meds, 'paracetamol'), isNull);
  });
}
