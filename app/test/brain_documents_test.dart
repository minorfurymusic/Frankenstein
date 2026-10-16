import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/documents/document_files.dart';
import 'package:frankstein/screens/brain/brain_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';

import 'support/fonts.dart';

/// Vários documentos de uma vez (ADR-19): a IA separa, cada arquivo segue
/// para o leitor do seu tipo e os dados pessoais escritos viram cartões.
const _dir = '../packages/ai/test/fixtures/real_examples';

class QueueTransport implements AiTransport {
  final List<Object> replies = [];
  final List<Map<String, dynamic>> bodies = [];
  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    bodies.add(jsonDecode(body) as Map<String, dynamic>);
    return AiHttpResponse(200, jsonEncode({
      'candidates': [
        {'content': {'parts': [{'text': jsonEncode(replies.removeAt(0))}]}},
      ],
    }));
  }
}

void main() {
  setUpAll(loadFigtree);

  late QueueTransport transport;
  late FakeDocumentPicker picker;
  late GlobalKey<NavigatorState> nav;
  late AppDependencies deps;

  setUp(() async {
    transport = QueueTransport();
    picker = FakeDocumentPicker();
    nav = GlobalKey<NavigatorState>();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(nav),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      documentPicker: picker,
      secretStore: MemorySecretStore()..values['gemini_api_key'] = 'CHAVE',
      aiTransport: transport,
    );
    await deps.ai.load();
    deps.ai.giveConsent();
  });
  tearDown(() => deps.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, theme: RltTheme.light(), home: Scaffold(body: BrainScreen(deps: deps))));
    await tester.pumpAndSettle();
  }

  testWidgets('receita + print + ficha da academia: cada um no seu lugar; peso, altura e condição viram cartões', (tester) async {
    deps.profileRepository.save(Profile(sex: BiologicalSex.male, birthDate: DateTime(1990), heightMeters: 1.80));
    final expected = jsonDecode(File('$_dir/expected.json').readAsStringSync()) as Map<String, dynamic>;
    final rx = (expected['receitas'] as List).first as Map<String, dynamic>;
    final rxFile = File('$_dir/${rx['file']}');
    picker.nextMany = [
      PickedDocument(bytes: rxFile.readAsBytesSync(), name: 'receita.png', mimeType: 'image/png'),
      PickedDocument(bytes: Uint8List.fromList([1, 2, 3]), name: 'print.png', mimeType: 'image/png'),
      PickedDocument(bytes: Uint8List.fromList([4, 5, 6]), name: 'academia.jpg', mimeType: 'image/jpeg'),
    ];
    transport.replies.addAll([
      {
        'files': [
          {'index': 1, 'kind': 'prescription'},
          {'index': 2, 'kind': 'other', 'description': 'Print da tela de metas de um app.'},
          {'index': 3, 'kind': 'workout_plan'},
        ],
        'body': {'weight_kg': 93.7, 'height_cm': 183},
        'history': [
          {'kind': 'condition', 'title': 'Hipertensão'},
        ],
      },
      rx['ai_reply'] as Object,
      {
        'name': 'Treino A',
        'exercises': [
          {'name': 'Supino reto', 'sets': 4, 'reps': 10, 'load_kg': 30},
          {'name': 'Puxada alta', 'sets': 3, 'reps': 12},
        ],
      },
    ]);

    await pump(tester);
    await tester.tap(find.byKey(const Key('chat_attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_many_gallery')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();

    // Uma chamada para separar (com os 3 arquivos) e uma por documento lido.
    expect(transport.bodies, hasLength(3));
    final sortParts = (transport.bodies.first['contents'] as List).single['parts'] as List;
    expect(sortParts.where((p) => p['inlineData'] != null), hasLength(3));
    expect(transport.bodies.first['systemInstruction'].toString(), contains('Nunca deduza doença a partir de remédio'));

    expect(find.byKey(const Key('brain_doc_prescription')), findsOneWidget);
    expect(find.textContaining('Arquivo 2 (print.png): Print da tela de metas de um app. Não há nada para registrar.'), findsOneWidget);
    expect(find.byKey(const Key('brain_doc_workoutPlan')), findsOneWidget);
    expect(find.textContaining('Treino A: 2 exercícios'), findsOneWidget);

    // Nada foi salvo ainda: são cartões.
    expect(find.text('Peso — 93,7 kg'), findsOneWidget);
    expect(find.text('Altura — 183 cm'), findsOneWidget);
    expect(find.text('Condição ou diagnóstico informado — Hipertensão'), findsOneWidget);
    expect(deps.core.queryByType(HealthEventType.weight), isEmpty);
    expect(deps.medicalHistory.list(), isEmpty);

    // Confirma os três.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('confirmation_confirm')).first);
      await tester.pumpAndSettle();
    }
    expect(deps.core.queryByType(HealthEventType.weight).single.payload['kg'], 93.7);
    expect(deps.profileRepository.load()!.heightMeters, closeTo(1.83, 1e-9));
    expect(deps.medicalHistory.list().single.title, 'Hipertensão');

    // Ficha de treino: revisar abre o plano já preenchido; salvar guarda.
    await tester.tap(find.byKey(const Key('brain_doc_review_workoutPlan')));
    await tester.pumpAndSettle();
    expect(find.text('Supino reto'), findsWidgets);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    final plan = deps.workoutRepository.listPlans().single;
    expect(plan.name, 'Treino A');
    expect(plan.exercises.map((e) => (e.targetSets, e.targetReps, e.targetLoadKg)), [(4, 10, 30.0), (3, 12, null)]);
    expect(find.text('Salvo em Exercícios › Academia'), findsOneWidget);
  });

  testWidgets('foto que não é comida como "Foto do prato": diz o que viu', (tester) async {
    picker.next = PickedDocument(bytes: Uint8List.fromList([1, 2, 3]), name: 'print.png', mimeType: 'image/png');
    transport.replies.add({'items': [], 'not_food': 'Print da tela de metas de um app.'});
    await pump(tester);
    await tester.tap(find.byKey(const Key('chat_attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_plate_gallery')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não vi comida nesta foto: Print da tela de metas de um app.'), findsOneWidget);
  });
}
