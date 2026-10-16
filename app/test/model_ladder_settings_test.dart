import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/documents/document_files.dart';
import 'package:frankstein/screens/account/brain_settings_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';

import 'support/fonts.dart';

class ListingTransport implements AiTransport, AiModelLister {
  final Map<String, AiHttpResponse> byModel = {};
  final List<String> calls = [];

  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    final m = url.pathSegments.last.split(':').first;
    calls.add(m);
    return byModel[m] ?? const AiHttpResponse(404, '{}');
  }

  @override
  Future<AiHttpResponse> get(Uri url, Map<String, String> headers) async => AiHttpResponse(
      200,
      jsonEncode({
        'models': [
          for (final (n, d) in [
            ('gemini-2.5-flash-lite', 'Gemini 2.5 Flash-Lite'),
            ('gemini-2.5-flash', 'Gemini 2.5 Flash'),
            ('gemini-3-flash-preview', 'Gemini 3 Flash Preview'),
          ])
            {
              'name': 'models/$n',
              'displayName': d,
              'supportedGenerationMethods': ['generateContent'],
            },
        ],
      }));
}

AiHttpResponse okText() => AiHttpResponse(
    200,
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': 'ok'},
            ],
          },
        },
      ],
    }));

const quota = AiHttpResponse(429, '{"error":{"status":"RESOURCE_EXHAUSTED"}}');

void main() {
  setUpAll(loadFigtree);

  late ListingTransport transport;
  late MemorySecretStore secrets;
  late AppDependencies deps;

  setUp(() {
    transport = ListingTransport();
    secrets = MemorySecretStore();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      documentPicker: FakeDocumentPicker(),
      secretStore: secrets,
      aiTransport: transport,
    );
  });
  tearDown(() => deps.close());

  test('testar a chave lê os modelos; a escada continua de onde parou e volta ao topo no dia seguinte', () async {
    transport.byModel['gemini-3-flash-preview'] = okText();
    await deps.ai.testAndSaveKey('CHAVE');
    expect(deps.ai.ladder, ['gemini-3-flash-preview', 'gemini-2.5-flash', 'gemini-2.5-flash-lite']);

    transport.byModel['gemini-3-flash-preview'] = quota;
    transport.byModel['gemini-2.5-flash'] = okText();
    transport.calls.clear();
    await (await deps.ai.client()).ping();
    expect(transport.calls, ['gemini-3-flash-preview', 'gemini-2.5-flash']);
    expect(deps.ai.lastModelLabel.value, 'Gemini 2.5 Flash');

    // Próximo pedido já começa no que respondeu.
    transport.calls.clear();
    await (await deps.ai.client()).ping();
    expect(transport.calls, ['gemini-2.5-flash']);

    // Num dia novo da cota (meia-noite do Pacífico), volta ao melhor.
    expect(deps.ai.ladderStart(DateTime.now().add(const Duration(days: 1))), 0);
    expect(deps.ai.ladderStart(), 1);
  });

  test('modelo escolhido à mão: só ele, sem descer', () async {
    secrets.values['gemini_api_key'] = 'CHAVE';
    deps.ai.setModelChoice('gemini-2.5-flash-lite');
    expect(deps.ai.ladder, ['gemini-2.5-flash-lite']);
    deps.ai.setModelChoice(AiSettings.auto);
    expect(deps.ai.ladder, GeminiClient.defaultLadder);
  });

  test('mensagens: limite gratuito acabou × servidores ocupados', () {
    expect(aiFailureMessage(const AiException(AiFailure.exhausted, null, 429)), contains('faturamento'));
    expect(aiFailureMessage(const AiException(AiFailure.exhausted, null, 503)), contains('ocupados'));
  });

  testWidgets('Conta › Cérebro: escolher o modelo salva na hora', (tester) async {
    transport.byModel['gemini-3-flash-preview'] = okText();
    await deps.ai.testAndSaveKey('CHAVE');
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: BrainSettingsScreen(deps: deps)));
    await tester.pumpAndSettle();
    expect(find.text('Automático (recomendado)'), findsOneWidget);
    await tester.tap(find.text('Modelo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai_model')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini 2.5 Flash').last);
    await tester.pumpAndSettle();
    expect(deps.ai.modelChoice, 'gemini-2.5-flash');
    expect(find.byKey(const Key('ai_refresh_models')), findsOneWidget);
  });
}
