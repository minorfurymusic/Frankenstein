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
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_core/health_core.dart';

import 'support/fonts.dart';

class OneReplyTransport implements AiTransport {
  Object? reply;
  int calls = 0;
  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    calls++;
    return AiHttpResponse(200, jsonEncode({
      'candidates': [
        {'content': {'parts': [{'text': jsonEncode(reply)}]}},
      ],
    }));
  }
}

/// Foto de produto embalado (decisão do usuário, 2026-10-20): a IA copia o
/// que está escrito; valores só da tabela da foto ou do item com o mesmo
/// código no celular — nunca estimados.
void main() {
  setUpAll(loadFigtree);

  const code = '7898987654322';
  late OneReplyTransport transport;
  late FakeDocumentPicker picker;
  late GlobalKey<NavigatorState> nav;
  late AppDependencies deps;

  setUp(() async {
    transport = OneReplyTransport();
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

  Future<void> sendPhoto(WidgetTester tester, Map<String, dynamic> package) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, theme: RltTheme.light(), home: Scaffold(body: BrainScreen(deps: deps))));
    await tester.pumpAndSettle();
    picker.next = PickedDocument(bytes: Uint8List.fromList([1, 2, 3]), name: 'lata.jpg', mimeType: 'image/jpeg');
    transport.reply = {'items': [], 'package': package};
    await tester.tap(find.byKey(const Key('chat_attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_plate_camera')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();
  }

  testWidgets('lata sem tabela na foto: lê marca e código, não estima e pede a foto da tabela', (tester) async {
    await sendPhoto(tester, {'brand': 'Bally', 'product': 'Energético', 'net_amount': 473, 'liquid': true, 'barcode': code});
    expect(find.textContaining('Li na embalagem: Energético Bally · 473 ml · código $code'), findsOneWidget);
    expect(find.textContaining('não estimo valores de produto embalado'), findsOneWidget);
    expect(find.byKey(const Key('confirmation_confirm')), findsNothing);
    expect(deps.core.queryAllVersions(HealthEventType.meal), isEmpty);
  });

  testWidgets('com a tabela na foto: valores do rótulo, sem "estimativa"; confirmar guarda o código para o leitor', (tester) async {
    await sendPhoto(tester, {
      'brand': 'Bally',
      'product': 'Energético',
      'net_amount': 473,
      'liquid': true,
      'barcode': code,
      'nutrition_per_100': {'kcal': 45, 'carbs_g': 11, 'sugar_g': 11},
    });
    expect(find.textContaining('Valores copiados da tabela da foto'), findsOneWidget);
    expect(find.textContaining('Energético Bally 473 ml'), findsOneWidget);
    expect(find.textContaining('kcal (do rótulo)'), findsOneWidget);
    expect(find.byKey(const Key('proposal_estimate')), findsNothing);

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    expect(deps.core.queryAllVersions(HealthEventType.meal), hasLength(1));
    final saved = deps.foodRepository.findByBarcode(code)!;
    expect((saved.name, saved.energyKcalPer100g, saved.carbohydratesPer100g), ('Energético Bally', 45.0, 11.0));
  });

  testWidgets('código que já está no celular: usa os valores de lá, mesmo sem tabela na foto', (tester) async {
    deps.nutrition.createBarcodeItem(barcode: code, name: 'Energético Bally', kcalPer100g: 45, carbsPer100g: 11);
    await sendPhoto(tester, {'brand': 'Bally', 'product': 'Energético', 'net_amount': 269, 'liquid': true, 'barcode': code});
    expect(find.textContaining('Valores do item com este código no seu celular'), findsOneWidget);
    expect(find.textContaining('Energético Bally 269 ml'), findsOneWidget);
  });

  test('código lido com dígito errado é descartado (não casa com produto errado)', () {
    expect(validRetailBarcode(code), isTrue);
    expect(validRetailBarcode('7898987654321'), isFalse);
    final r = parsePlateEstimate({
      'items': [
        {'name': 'Energético', 'grams': 473, 'kcal': 200, 'protein_g': 0, 'carbs_g': 50, 'fat_g': 0},
      ],
      'package': {'brand': 'Bally', 'barcode': '7898 98765432-1'},
    });
    expect(r.items, isEmpty, reason: 'com embalagem, nada estimado');
    expect((r.package!.displayName, r.package!.barcode), ('Bally', null));
  });
}
