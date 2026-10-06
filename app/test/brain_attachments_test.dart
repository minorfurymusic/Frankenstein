import 'dart:convert';
import 'dart:io';

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
import 'package:frankstein_health_records/health_records.dart';

import 'support/fonts.dart';

/// Os 12 exemplos reais baixados da internet (fontes e licenças em
/// `packages/ai/test/fixtures/real_examples/FONTES.md`). O Gemini de verdade
/// não é alcançável no desenvolvimento: o transporte falso devolve a leitura
/// correta de cada arquivo (`ai_reply`) e o teste confere o resto do caminho —
/// os bytes exatos que vão, a instrução certa, os cartões e o que é salvo.
const _dir = '../packages/ai/test/fixtures/real_examples';
final Map<String, dynamic> _expected = jsonDecode(File('$_dir/expected.json').readAsStringSync()) as Map<String, dynamic>;
List<Map<String, dynamic>> _cases(String group) => (_expected[group] as List).cast<Map<String, dynamic>>();

class RecordingTransport implements AiTransport {
  Object? reply;
  final List<Map<String, dynamic>> bodies = [];
  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    bodies.add(jsonDecode(body) as Map<String, dynamic>);
    return AiHttpResponse(200, jsonEncode({
      'candidates': [
        {'content': {'parts': [{'text': jsonEncode(reply)}]}},
      ],
    }));
  }

  List<int> get sentBytes {
    final parts = (bodies.single['contents'] as List).single['parts'] as List;
    return base64Decode((parts.firstWhere((p) => p['inlineData'] != null) as Map)['inlineData']['data'] as String);
  }

  String get sentMime {
    final parts = (bodies.single['contents'] as List).single['parts'] as List;
    return (parts.firstWhere((p) => p['inlineData'] != null) as Map)['inlineData']['mimeType'] as String;
  }

  String get system => bodies.single['systemInstruction'].toString();
}

void main() {
  setUpAll(loadFigtree);

  late RecordingTransport transport;
  late MemorySecretStore secrets;
  late FakeDocumentPicker picker;
  late GlobalKey<NavigatorState> nav;
  late AppDependencies deps;

  setUp(() async {
    transport = RecordingTransport();
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
  });
  tearDown(() => deps.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, theme: RltTheme.light(), home: Scaffold(body: BrainScreen(deps: deps))));
    await tester.pumpAndSettle();
  }

  /// Anexa pelo botão do Cérebro, como a pessoa faria.
  Future<PickedDocument> attach(WidgetTester tester, Map<String, dynamic> c, String kind, String source) async {
    final file = File('$_dir/${c['file']}');
    final doc = PickedDocument(bytes: file.readAsBytesSync(), name: file.uri.pathSegments.last, mimeType: c['mime'] as String);
    picker.next = doc;
    transport.reply = c['ai_reply'];
    await tester.tap(find.byKey(const Key('chat_attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('attach_${kind}_$source')));
    await tester.pumpAndSettle();
    return doc;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('document_save')));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
  }

  String day(String iso) {
    final p = iso.split('-');
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  testWidgets('sem chave não há botão de anexar; com chave, o primeiro anexo pede consentimento e "Não agora" não envia', (tester) async {
    await deps.ai.removeKey();
    await pump(tester);
    expect(find.byKey(const Key('chat_attach')), findsNothing);

    secrets.values['gemini_api_key'] = 'CHAVE';
    await deps.ai.load();
    await tester.pumpAndSettle();
    await attach(tester, _cases('pratos').first, 'plate', 'gallery');
    expect(find.byKey(const Key('ai_consent')), findsOneWidget);
    expect(find.textContaining('a foto do prato'), findsWidgets);
    await tester.tap(find.byKey(const Key('ai_consent_no')));
    await tester.pumpAndSettle();
    expect(transport.bodies, isEmpty);
    expect(find.text('Ok, não enviei nada.'), findsOneWidget);
  });

  for (final c in _cases('pratos')) {
    testWidgets('prato real ${c['file']}: foto vai inteira, vira cartão estimado, confirma e vai para a Galeria', (tester) async {
      deps.ai.giveConsent();
      await pump(tester);
      final doc = await attach(tester, c, 'plate', 'camera');

      expect(transport.sentBytes, doc.bytes);
      expect(transport.sentMime, 'image/jpeg');
      expect(transport.system, contains('foto'));
      expect(find.byKey(const Key('brain_attached_plate')), findsOneWidget);

      final reply = c['ai_reply'] as Map<String, dynamic>;
      final items = (reply['items'] as List).cast<Map<String, dynamic>>();
      final kcal = items.fold<double>(0, (s, i) => s + (i['kcal'] as num));
      for (final i in items) {
        expect(find.textContaining('${i['name']} ${i['grams']} g'), findsOneWidget, reason: '${i['name']}');
      }
      expect(find.byKey(const Key('proposal_estimate')), findsOneWidget);
      // Gabarito medido em balança (Nutrition5k) bate com o que o cartão mostra.
      expect(kcal, closeTo((c['truth'] as Map)['kcal'] as num, 1.5));

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('confirmation_confirm')));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      final meal = deps.core.queryByType(HealthEventType.meal).single;
      expect(meal.payload['meal_type'], reply['meal_type']);
      expect((meal.payload['totals'] as Map)['energy_kcal'], closeTo(kcal, 0.5));
      expect(deps.nutrition.platePhotos().single.mealEventId, meal.id);
      expect(deps.nutrition.myItems(), isEmpty);
    });
  }

  for (final c in _cases('receitas')) {
    testWidgets('receita ${c['file']}: lida no Cérebro, revisada no formulário e salva com os remédios', (tester) async {
      deps.ai.giveConsent();
      await pump(tester);
      final doc = await attach(tester, c, 'prescription', 'gallery');

      expect(transport.sentBytes, doc.bytes);
      expect(transport.sentMime, c['mime']);
      expect(transport.system, contains('receitas médicas'));
      final reply = c['ai_reply'] as Map<String, dynamic>;
      final meds = (reply['medicines'] as List).cast<Map<String, dynamic>>();
      final summary = tester.widget<Text>(find.byKey(const Key('brain_doc_summary_prescription'))).data!;
      expect(summary, contains(reply['doctor'] as String));
      expect(summary, contains(day(reply['date'] as String)));
      expect(summary, contains(meds.length == 1 ? '1 remédio' : '${meds.length} remédios'));

      await tester.tap(find.byKey(const Key('brain_doc_review_prescription')));
      await tester.pumpAndSettle();
      expect(transport.bodies, hasLength(1), reason: 'o formulário usa a leitura já feita, sem chamar a IA de novo');
      expect(find.widgetWithText(TextField, reply['doctor'] as String), findsOneWidget);
      expect(find.text(day(reply['date'] as String)), findsOneWidget);
      for (var i = 0; i < meds.length; i++) {
        expect(find.byKey(Key('rx_med_$i')), findsOneWidget);
      }
      await save(tester);

      final rx = deps.documents.list(HealthDocumentKind.prescription).single;
      expect(rx.title, reply['doctor']);
      expect(rx.date!.toIso(), reply['date']);
      expect(rx.files.single.originalName, doc.name);
      expect(find.text('Salvo em Saúde › Receitas médicas'), findsOneWidget);
    });
  }

  for (final c in _cases('exames')) {
    testWidgets('exame ${c['file']}: PDF lido no Cérebro, valores com a unidade do laudo e salvo', (tester) async {
      deps.ai.giveConsent();
      await pump(tester);
      final doc = await attach(tester, c, 'exam', 'pdf');

      expect(transport.sentBytes, doc.bytes);
      expect(transport.sentMime, 'application/pdf');
      expect(transport.system, contains('Não converta unidades'));
      final reply = c['ai_reply'] as Map<String, dynamic>;
      final markers = (reply['markers'] as List).cast<Map<String, dynamic>>();
      final summary = tester.widget<Text>(find.byKey(const Key('brain_doc_summary_exam'))).data!;
      expect(summary, contains('${markers.length} valores lidos'));
      expect(summary, contains(day(reply['date'] as String)));

      await tester.tap(find.byKey(const Key('brain_doc_review_exam')));
      await tester.pumpAndSettle();
      expect(transport.bodies, hasLength(1));
      expect(find.text('Valores lidos'), findsOneWidget);
      await save(tester);

      final exam = deps.documents.list(HealthDocumentKind.exam).single;
      expect(exam.date!.toIso(), reply['date']);
      final truth = ((c['truth'] as Map)['markers'] as Map).cast<String, dynamic>();
      expect(exam.markers, hasLength(truth.length));
      for (final m in exam.markers) {
        final t = truth[m.name] as List;
        expect(m.value, t[0], reason: m.name);
        expect(m.unit, t[1], reason: m.name);
      }
      expect(find.text('Salvo em Saúde › Exames'), findsOneWidget);
    });
  }
}
