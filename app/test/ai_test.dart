import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/documents/document_files.dart';
import 'package:frankstein/screens/account/brain_settings_screen.dart';
import 'package:frankstein/screens/health/documents_screens.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_records/health_records.dart';

import 'support/fonts.dart';

class FakeTransport implements AiTransport {
  final List<AiHttpResponse> replies = [];
  final List<Map<String, dynamic>> bodies = [];
  final List<Map<String, String>> headers = [];

  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> h, String body) async {
    headers.add(h);
    bodies.add(jsonDecode(body) as Map<String, dynamic>);
    return replies.removeAt(0);
  }
}

AiHttpResponse reply(Object json) => AiHttpResponse(
      200,
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': jsonEncode(json)},
              ],
            },
          },
        ],
      }),
    );

void main() {
  setUpAll(loadFigtree);

  late FakeTransport transport;
  late MemorySecretStore secrets;
  late FakeDocumentPicker picker;
  late AppDependencies deps;

  setUp(() {
    transport = FakeTransport();
    secrets = MemorySecretStore();
    picker = FakeDocumentPicker();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      documentPicker: picker,
      secretStore: secrets,
      aiTransport: transport,
    );
  });
  tearDown(() => deps.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: home));
    await tester.pumpAndSettle();
  }

  Future<void> activateKey() async {
    secrets.values['gemini_api_key'] = 'CHAVE';
    await deps.ai.load();
  }

  testWidgets('Conta › Cérebro: testar e salvar guarda a chave no cofre; apagar volta ao básico', (tester) async {
    await pump(tester, BrainSettingsScreen(deps: deps));
    expect(find.byKey(const Key('ai_basic')), findsOneWidget);

    transport.replies.add(const AiHttpResponse(400, '{"error":{"message":"API key not valid.","status":"INVALID_ARGUMENT"}}'));
    await tester.enterText(find.byKey(const Key('ai_key_field')), 'ruim');
    await tester.tap(find.byKey(const Key('ai_test_save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('recusou esta chave'), findsOneWidget);
    expect(secrets.values, isEmpty);

    transport.replies.add(reply({'ok': true}));
    await tester.enterText(find.byKey(const Key('ai_key_field')), '  AIza-boa  ');
    await tester.tap(find.byKey(const Key('ai_test_save')));
    await tester.pumpAndSettle();
    expect(secrets.values['gemini_api_key'], 'AIza-boa');
    expect(transport.headers.last['x-goog-api-key'], 'AIza-boa');
    // O teste da chave não leva dado de saúde.
    expect(jsonEncode(transport.bodies.last), contains('Responda apenas: ok'));
    expect(find.byKey(const Key('ai_active')), findsOneWidget);
    // A chave não fica no banco nem na exportação.
    expect(deps.profileRepository.getSetting('gemini_api_key'), isNull);

    deps.ai.giveConsent();
    await tester.tap(find.byKey(const Key('ai_remove_key')));
    await tester.pumpAndSettle();
    expect(secrets.values, isEmpty);
    expect(deps.ai.consentedAt, isNull);
    expect(find.byKey(const Key('ai_basic')), findsOneWidget);
  });

  testWidgets('exame: anexar o PDF → consentimento → valores lidos preenchem o formulário (estimativa) → salvar', (tester) async {
    await activateKey();
    transport.replies.add(reply({
      'title': 'Hemograma completo',
      'date': '2026-09-25',
      'category': 'blood',
      'markers': [
        {'name': 'Glicemia de jejum', 'value': 102, 'unit': 'mg/dL', 'reference_low': 70, 'reference_high': 99},
        {'name': 'HbA1c', 'value': 5.9, 'unit': '%'},
      ],
    }));
    await pump(tester, ExamsScreen(deps: deps));
    await tester.tap(find.byKey(const Key('document_add')));
    await tester.pumpAndSettle();
    final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4 laudo'));
    picker.next = PickedDocument(bytes: pdf, name: 'laudo.pdf', mimeType: 'application/pdf');
    await tester.tap(find.byKey(const Key('document_pdf')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_consent')), findsOneWidget);
    expect(find.text(AiSettings.providerName), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_consent_yes')));
    await tester.pumpAndSettle();

    final sent = (transport.bodies.single['contents'] as List).single['parts'] as List;
    expect(base64Decode(sent.first['inlineData']['data'] as String), pdf);
    expect(find.text('Valores lidos'), findsOneWidget);
    expect(find.byKey(const Key('marker_estimate')), findsOneWidget);
    expect(find.text('Hemograma completo'), findsOneWidget);
    expect(find.text('102 mg/dL'), findsOneWidget);
    expect(find.text('25/09/2026'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('document_save')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final exam = deps.documents.list(HealthDocumentKind.exam).single;
    expect(exam.title, 'Hemograma completo');
    expect(exam.date, LocalDate(2026, 9, 25));
    expect(exam.markers.map((m) => m.name), ['Glicemia de jejum', 'HbA1c']);
    expect(exam.markers.first.referenceHigh, 99);
    expect(deps.ai.consentedAt, isNotNull);
  });

  testWidgets('"Não agora" no consentimento: nada sai do celular', (tester) async {
    await activateKey();
    await pump(tester, ExamsScreen(deps: deps));
    await tester.tap(find.byKey(const Key('document_add')));
    await tester.pumpAndSettle();
    picker.next = PickedDocument(bytes: Uint8List(4), name: 'foto.jpg', mimeType: 'image/jpeg');
    await tester.tap(find.byKey(const Key('document_gallery')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai_consent_no')));
    await tester.pumpAndSettle();
    expect(transport.bodies, isEmpty);
    expect(deps.ai.consentedAt, isNull);
  });

  testWidgets('sem chave: só o convite para ativar a IA, sem rede', (tester) async {
    await pump(tester, ExamsScreen(deps: deps));
    await tester.tap(find.byKey(const Key('document_add')));
    await tester.pumpAndSettle();
    picker.next = PickedDocument(bytes: Uint8List(4), name: 'foto.jpg', mimeType: 'image/jpeg');
    await tester.tap(find.byKey(const Key('document_take_photo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exam_ai_hint')), findsOneWidget);
    expect(find.byKey(const Key('ai_consent')), findsNothing);
    expect(transport.bodies, isEmpty);
  });

  testWidgets('erro da IA aparece em português e dá para tentar de novo', (tester) async {
    await activateKey();
    deps.ai.giveConsent();
    transport.replies.add(const AiHttpResponse(429, '{"error":{"status":"RESOURCE_EXHAUSTED"}}'));
    await pump(tester, ExamsScreen(deps: deps));
    await tester.tap(find.byKey(const Key('document_add')));
    await tester.pumpAndSettle();
    picker.next = PickedDocument(bytes: Uint8List(4), name: 'foto.jpg', mimeType: 'image/jpeg');
    await tester.tap(find.byKey(const Key('document_gallery')));
    await tester.pumpAndSettle();
    expect(find.textContaining('limite de uso'), findsOneWidget);
    expect(find.text('Ler de novo com a IA'), findsOneWidget);
  });
}
