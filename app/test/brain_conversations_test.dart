import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/data/data_export.dart';
import 'package:frankstein/screens/brain/brain_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_core/health_core.dart';

import 'support/fonts.dart';

class FakeTransport implements AiTransport {
  final List<Object> replies = [];
  final List<String> prompts = [];
  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    final parts = ((jsonDecode(body) as Map)['contents'] as List).single['parts'] as List;
    prompts.add(parts.last['text'] as String);
    return AiHttpResponse(200, jsonEncode({
      'candidates': [
        {'content': {'parts': [{'text': jsonEncode(replies.removeAt(0))}]}},
      ],
    }));
  }
}

void main() {
  setUpAll(loadFigtree);

  late FakeTransport transport;
  late GlobalKey<NavigatorState> nav;
  late AppDependencies deps;

  setUp(() async {
    transport = FakeTransport();
    nav = GlobalKey<NavigatorState>();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(nav),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      secretStore: MemorySecretStore()..values['gemini_api_key'] = 'CHAVE',
      aiTransport: transport,
    );
    await deps.ai.load();
    deps.ai.giveConsent();
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
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();
  }

  testWidgets('a conversa fica guardada: aparece na lista com o que foi salvo e reabre como estava', (tester) async {
    transport.replies.add({
      'reply': 'Anotei.',
      'water': [
        {'amount_ml': 500},
      ],
      'medication_doses': [
        {'name': 'Dipirona', 'dose_amount': 500, 'dose_unit': 'mg', 'status': 'taken'},
      ],
    });
    await pump(tester);
    await send(tester, 'bebi 500 ml de água e tomei dipirona 500 mg');
    await tester.tap(find.byKey(const Key('confirmation_confirm')).first); // água
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmation_cancel'))); // dipirona
    await tester.pumpAndSettle();

    final saved = deps.conversations.list().single;
    expect(saved.title, 'bebi 500 ml de água e tomei dipirona 500 …'); // título curto, cortado em 42
    expect(saved.summary, '1 item salvo · Nutrição');

    // Outra sessão do app: a tela começa vazia e a conversa está na lista.
    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    expect(find.text('Conte o que aconteceu'), findsOneWidget);
    await tester.tap(find.byKey(const Key('brain_history')));
    await tester.pumpAndSettle();
    expect(find.text('1 item salvo · Nutrição'), findsOneWidget);
    await tester.tap(find.byKey(Key('conversation_${saved.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Salvo em Nutrição › Água'), findsOneWidget);
    expect(find.text('Descartado — nada foi salvo'), findsOneWidget);
    expect(find.byKey(const Key('confirmation_confirm')), findsNothing);

    // Entra na exportação.
    expect((buildFullExport(deps)['brain_conversations'] as List).single['id'], saved.id);
  });

  testWidgets('a IA recebe o que já foi dito nesta conversa: "pode salvar a dipirona" volta a virar cartão', (tester) async {
    transport.replies
      ..add({
        'reply': 'Anotei.',
        'medication_doses': [
          {'name': 'Dipirona', 'dose_amount': 500, 'dose_unit': 'mg', 'status': 'taken'},
        ],
      })
      ..add({
        'reply': 'Certo.',
        'medication_doses': [
          {'name': 'Dipirona', 'dose_amount': 500, 'dose_unit': 'mg', 'status': 'taken', 'at': '2026-10-06T09:00:00-03:00'},
        ],
      });
    await pump(tester);
    await send(tester, 'tomei dipirona 500 mg');
    await tester.tap(find.byKey(const Key('confirmation_cancel')));
    await tester.pumpAndSettle();
    await send(tester, 'a dipirona foi às 9h mesmo, pode salvar');

    expect(transport.prompts.first, isNot(contains('Conversa até agora')));
    final second = transport.prompts.last;
    expect(second, contains('Conversa até agora:'));
    expect(second, contains('Pessoa: tomei dipirona 500 mg'));
    expect(second, contains('Cartão descartado: Remédio tomado — Dipirona'));
    expect(second, isNot(contains('pode salvar\nPessoa'))); // a mensagem nova vai uma vez só
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.medicationDose), hasLength(1));
  });

  testWidgets('remédio novo: a IA pergunta, oferece horários (nunca dose) e cadastra quando tudo foi dito', (tester) async {
    transport.replies
      ..add({
        'reply': 'Em quais horários você toma a vitamina D? Também preciso da dose (ex.: 2.000 UI).',
        'suggestions': ['08:00', '20:00', '2000 UI'],
      })
      ..add({
        'reply': 'Cadastrei.',
        'new_medications': [
          {'name': 'Vitamina D', 'dose_amount': 2000, 'dose_unit': 'UI', 'times': ['08:00']},
        ],
      });
    await pump(tester);
    await send(tester, 'comecei a tomar vitamina D');
    expect(find.byKey(const Key('brain_reply_08:00')), findsOneWidget);
    expect(find.byKey(const Key('brain_reply_20:00')), findsOneWidget);
    expect(find.byKey(const Key('brain_reply_2000 UI')), findsNothing, reason: 'resposta rápida nunca oferece dose');

    await tester.tap(find.byKey(const Key('brain_reply_08:00')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('brain_reply_08:00')), findsNothing);
    expect(transport.prompts.last, contains('Mensagem: 08:00'));
    expect(find.text('Vitamina D 2.000 UI'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    final med = deps.medicationRepository.listAll().single;
    expect((med.name, med.doseAmount, med.doseUnit), ('Vitamina D', 2000.0, 'UI'));
    expect(med.timesOfDay, [8 * 60]);
  });

  testWidgets('editar antes de confirmar: intensidade do sintoma e ml da água', (tester) async {
    transport.replies.add({
      'reply': 'Anotei.',
      'water': [
        {'amount_ml': 500},
      ],
      'symptoms': [
        {'name': 'Dor de cabeça'},
      ],
    });
    await pump(tester);
    await send(tester, 'bebi meio litro e estou com dor de cabeça');

    await tester.tap(find.byTooltip('Editar Água — 500 ml'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('proposal_ml')), '750');
    await tester.tap(find.byKey(const Key('confirmation_confirm')).first);
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.water).single.payload['amount_ml'], 750);

    await tester.tap(find.byTooltip('Editar Sintoma — Dor de cabeça'));
    await tester.pumpAndSettle();
    final slider = tester.getRect(find.byKey(const Key('proposal_intensity')));
    // Trilho do Slider tem margem nas pontas; 80% da largura útil ≈ 8.
    await tester.tapAt(Offset(slider.left + 24 + (slider.width - 48) * 0.8, slider.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Intensidade: 8 de 10'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.symptom).single.payload['intensity'], 8);
  });

  testWidgets('apagar uma conversa da lista não apaga o que foi salvo', (tester) async {
    transport.replies.add({
      'reply': 'Anotei.',
      'water': [
        {'amount_ml': 300},
      ],
    });
    await pump(tester);
    await send(tester, 'bebi um copo de água');
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    final id = deps.conversations.list().single.id;

    await tester.tap(find.byKey(const Key('brain_history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('conversation_delete_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conversation_delete_confirm')));
    await tester.pumpAndSettle();
    expect(deps.conversations.list(), isEmpty);
    expect(find.byKey(const Key('conversations_empty')), findsOneWidget);
    expect(deps.core.queryByType(HealthEventType.water), hasLength(1));
  });
}
