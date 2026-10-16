import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/documents/document_files.dart';
import 'package:frankstein/screens/brain/brain_screen.dart';
import 'package:frankstein/screens/brain/brain_text.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_core/health_core.dart';

import 'support/fonts.dart';

class FakeTransport implements AiTransport {
  final List<Object> replies = [];
  final List<String> bodies = [];
  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    bodies.add(body);
    return AiHttpResponse(200, jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(replies.removeAt(0))},
            ],
          },
        },
      ],
    }));
  }
}

void main() {
  setUpAll(loadFigtree);

  late FakeTransport transport;
  late MemorySecretStore secrets;
  late FakeDocumentPicker picker;
  late GlobalKey<NavigatorState> nav;
  late AppDependencies deps;

  setUp(() async {
    transport = FakeTransport();
    secrets = MemorySecretStore()..values['gemini_api_key'] = 'CHAVE';
    picker = FakeDocumentPicker();
    nav = GlobalKey<NavigatorState>();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(nav),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      documentPicker: picker,
      secretStore: secrets,
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

  testWidgets('foto com texto: o anexo espera no campo, o texto vai junto para a IA; o anexo pode ser mandado de novo', (tester) async {
    await pump(tester);
    picker.next = PickedDocument(bytes: Uint8List.fromList([1, 2, 3]), name: 'pastel.jpg', mimeType: 'image/jpeg');
    await tester.tap(find.byKey(const Key('chat_attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_plate_gallery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat_pending_attachment')), findsOneWidget);
    expect(transport.bodies, isEmpty);

    transport.replies.add({
      'meal_type': 'snack',
      'items': [
        {'name': 'Pastel de carne (sem a borda)', 'grams': 90, 'kcal': 250, 'protein_g': 9, 'carbs_g': 22, 'fat_g': 14},
      ],
    });
    await send(tester, 'pastel de carne, não comi a borda');
    expect(transport.bodies.single, contains('A pessoa disse: \\"pastel de carne, não comi a borda\\"'));
    expect(find.text('pastel de carne, não comi a borda'), findsOneWidget);
    expect(find.byKey(const Key('chat_pending_attachment')), findsNothing);
    await tester.tap(find.byKey(const Key('confirmation_cancel')));
    await tester.pumpAndSettle();

    // Tocar no anexo enviado: "Mandar de novo" volta para o campo.
    await tester.tap(find.byKey(const Key('brain_attached_plate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brain_attach_resend')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat_pending_attachment')), findsOneWidget);
  });

  testWidgets('cartão da refeição: muda nome e refeição; a observação faz a IA recalcular só com texto', (tester) async {
    transport.replies.add({
      'reply': 'Anotei.',
      'meals': [
        {
          'meal_type': 'breakfast',
          'items': [
            {'name': 'Café', 'grams': 660, 'liquid': true, 'kcal': 13, 'protein_g': 1, 'carbs_g': 0, 'fat_g': 0},
            {'name': 'Açúcar', 'grams': 30, 'kcal': 116, 'protein_g': 0, 'carbs_g': 30, 'fat_g': 0},
          ],
        },
      ],
    });
    await pump(tester);
    await send(tester, 'tomei 2 copos de café com 15 g de açúcar em cada');
    // A instrução separa o que vai na bebida e pede o total do item.
    expect(transport.bodies.first, contains('Nunca conte o mesmo ingrediente duas vezes'));

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('proposal_name_1')), 'Açúcar refinado');
    await tester.tap(find.byKey(const Key('proposal_meal_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanche').last);
    await tester.pumpAndSettle();

    transport.replies.add({
      'items': [
        {'name': 'Café', 'grams': 660, 'kcal': 13, 'protein_g': 1, 'carbs_g': 0, 'fat_g': 0},
        {'name': 'Açúcar refinado', 'grams': 15, 'kcal': 58, 'protein_g': 0, 'carbs_g': 15, 'fat_g': 0},
      ],
    });
    await tester.enterText(find.byKey(const Key('proposal_note')), 'só um copo tinha açúcar');
    await tester.tap(find.byKey(const Key('proposal_refine')));
    await tester.pumpAndSettle();
    final refine = transport.bodies.last;
    expect(refine, contains('Açúcar refinado: 30.0 g'));
    expect(refine, contains('só um copo tinha açúcar'));
    expect(refine, isNot(contains('inlineData')));

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    final meal = deps.core.queryByType(HealthEventType.meal).single;
    expect(meal.payload['meal_type'], 'snack');
    expect((meal.payload['totals'] as Map)['energy_kcal'], closeTo(71, 0.6));
    final items = (meal.payload['items'] as List).cast<Map>();
    expect(items.first['unit'], 'ml');
  });

  testWidgets('remédio novo: cartão editável (horários, dose, início) e "desde" vem da mensagem; condição vira histórico', (tester) async {
    transport.replies.add({
      'reply': 'Anotei.',
      'new_medications': [
        {'name': 'Pantoprazol', 'dose_amount': 20, 'dose_unit': 'mg', 'times': ['06:30', '17:30'], 'start_date': '2026-02-01'},
      ],
      'history_items': [
        {'kind': 'condition', 'title': 'Hipertensão'},
      ],
    });
    await pump(tester);
    await send(tester, 'tenho hipertensão, tomo pantoprazol 20 mg 30 min antes do enalapril pela manhã desde 01/02/2026');
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('proposal_med_start')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('proposal_med_start'))).controller!.text, '01/02/2026');
    await tester.enterText(find.byKey(const Key('proposal_med_times')), '6h30');
    await tester.tap(find.byKey(const Key('confirmation_confirm')).first);
    await tester.pumpAndSettle();
    final med = deps.medicationRepository.listAll().single;
    expect(med.name, 'Pantoprazol');
    expect(med.timesOfDay, [6 * 60 + 30]);
    expect(med.startDate.toString(), '2026-02-01');

    // Os cartões vêm um de cada vez: depois do remédio, a condição.
    expect(find.textContaining('Hipertensão'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    expect(deps.medicalHistory.list().single.title, 'Hipertensão');
  });

  testWidgets('mensagem longa: condição, 2 remédios e refeição viram cartões; remédio sem horário avisa em vez de sumir', (tester) async {
    transport.replies.add({
      'reply': 'Anotei.',
      'history_items': [
        {'kind': 'condition', 'title': 'Hipertensão', 'date': '2026-02-01'},
      ],
      'new_medications': [
        {'name': 'Enalapril', 'dose_amount': 20, 'dose_unit': 'mg', 'times': ['07:00', '18:00'], 'start_date': '2026-02-01'},
        {'name': 'Pantoprazol', 'dose_amount': 20, 'dose_unit': 'mg', 'times': ['06:30']},
        {'name': 'Losartana'},
      ],
      'meals': [
        {
          'meal_type': 'lunch',
          'items': [
            {'name': 'Frango grelhado', 'grams': 400, 'kcal': 660, 'protein_g': 100, 'carbs_g': 0, 'fat_g': 28},
          ],
        },
      ],
    });
    await pump(tester);
    await send(tester, 'sou hipertenso desde 01/02/2026, tomo enalapril 20 mg às 7 e 18h e pantoprazol 20 mg meia hora antes pela manhã; almocei 400 g de frango');
    expect(find.textContaining('Para cadastrar Losartana, me diga a dose e os horários'), findsOneWidget);
    // Os cartões vêm um de cada vez; confirmar todos grava tudo.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('confirmation_confirm')).first);
      await tester.pumpAndSettle();
    }
    expect([for (final m in deps.medicationRepository.listAll()) m.name]..sort(), ['Enalapril', 'Pantoprazol']);
    expect(deps.medicalHistory.list().single.title, 'Hipertensão');
    expect(deps.core.queryByType(HealthEventType.meal), hasLength(1));
    expect(transport.bodies.single, contains('registre TODAS'));
  });

  testWidgets('tocar na própria mensagem abre Copiar e Editar e mandar de novo', (tester) async {
    transport.replies.add({'reply': 'Ok.'});
    await pump(tester);
    await send(tester, 'oi');
    await tester.tap(find.text('oi'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('brain_msg_copy')), findsOneWidget);
    expect(find.byKey(const Key('brain_msg_edit')), findsOneWidget);
  });

  test('resumo do dia: distância estimada pelos passos; corrida/caminhada só quando gravada', () {
    final data = {
      'steps': {'total': 3590},
      'meals': {'total_energy_kcal': 900, 'count': 2},
      'water': {'total_amount_ml': 2500},
      'workouts': {'count': 0},
      'runs': {'total_distance_meters': 0},
    };
    final text = describeReadResult('get_daily_summary', data, stepMeters: 0.75);
    expect(text, contains('3.590 passos (≈ 2,7 km pela sua passada)'));
    expect(text, isNot(contains('corrida')));
  });
}
