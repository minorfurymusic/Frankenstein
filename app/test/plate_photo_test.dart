import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/data/data_export.dart';
import 'package:frankstein/documents/document_files.dart';
import 'package:frankstein/screens/nutrition/plate_photo_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import 'support/fonts.dart';

final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

class FakeTransport implements AiTransport {
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

const estimate = {
  'meal_type': 'lunch',
  'items': [
    {'name': 'Arroz branco', 'grams': 150, 'kcal': 192, 'protein_g': 3.8, 'carbs_g': 42, 'fat_g': 0.3},
    {'name': 'Feijão carioca', 'grams': 100, 'kcal': 76, 'protein_g': 4.8, 'carbs_g': 13.6, 'fat_g': 0.5},
    {'name': 'Frango grelhado', 'grams': 120, 'kcal': 191, 'protein_g': 38, 'carbs_g': 0, 'fat_g': 3},
    {'name': 'Salada de alface e tomate', 'grams': 50, 'kcal': 9, 'protein_g': 0.6, 'carbs_g': 1.7, 'fat_g': 0.1},
  ],
};

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
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('foto do prato com peso: a IA estima, você ajusta e confirma; vai para a galeria', (tester) async {
    secrets.values['gemini_api_key'] = 'CHAVE';
    await deps.ai.load();
    transport.replies.add(estimate);
    await pump(tester, Scaffold(body: Builder(builder: (context) {
      return TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlatePhotoScreen(deps: deps))),
        child: const Text('abrir'),
      );
    })));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    picker.next = PickedDocument(bytes: _png, name: 'prato.png', mimeType: 'image/png');
    await tester.tap(find.byKey(const Key('plate_camera')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plate_weight')), '420');
    await tester.tap(find.byKey(const Key('plate_estimate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai_consent')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_consent_yes')));
    await tester.pumpAndSettle();

    final sent = (transport.bodies.single['contents'] as List).single['parts'] as List;
    expect(sent.first['inlineData']['mimeType'], 'image/png');
    expect(sent.last['text'], contains('420 g'));
    expect(find.text('Encontrei 4 alimentos:'), findsOneWidget);
    expect(find.text('REFEIÇÃO · Almoço'), findsOneWidget);
    expect(find.textContaining('468 kcal', findRichText: true), findsOneWidget); // 192 + 76 + 191 + 9

    // Menos arroz: 150 g → 100 g recalcula.
    await tester.tap(find.byKey(const Key('plate_item_0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plate_grams_input')), '100');
    await tester.tap(find.byKey(const Key('plate_grams_ok')));
    await tester.pumpAndSettle();
    expect(find.text('128 kcal'), findsOneWidget);
    // Tira a salada.
    await tester.tap(find.descendant(of: find.byKey(const Key('plate_item_3')), matching: find.byIcon(Icons.close)));
    await tester.pumpAndSettle();
    expect(find.text('Encontrei 3 alimentos:'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('plate_confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final meal = deps.core.queryByType(HealthEventType.meal).single;
    expect(meal.payload['meal_type'], 'lunch');
    final items = (meal.payload['items'] as List).cast<Map<String, dynamic>>();
    expect(items.map((i) => i['input_method']).toSet(), {'photo'});
    expect(items.map((i) => i['grams']), [100, 100, 120]);
    expect(deps.dayRead.totals(DateTime.now()).energyKcal, closeTo(128 + 76 + 191, 0.5));
    // Não polui "Meus itens".
    expect(deps.nutrition.myItems(), isEmpty);
    final photos = deps.nutrition.platePhotos();
    expect(photos.single.mealEventId, meal.id);
    expect(photos.single.mealType, MealType.lunch);
    expect(buildFullExport(deps)['plate_photos'], hasLength(1));

    await pump(tester, Scaffold(body: PlateGalleryView(deps: deps)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.byKey(Key('gallery_${meal.id}')), findsOneWidget);
    expect(find.descendant(of: find.byKey(Key('gallery_${meal.id}')), matching: find.textContaining('Almoço')), findsOneWidget);
  });

  testWidgets('sem chave: só o convite; "Não agora" no consentimento não envia', (tester) async {
    await pump(tester, PlatePhotoScreen(deps: deps));
    picker.next = PickedDocument(bytes: _png, name: 'prato.png', mimeType: 'image/png');
    await tester.tap(find.byKey(const Key('plate_gallery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plate_ai_hint')), findsOneWidget);
    expect(transport.bodies, isEmpty);

    secrets.values['gemini_api_key'] = 'CHAVE';
    await deps.ai.load();
    await tester.pump();
    await tester.tap(find.byKey(const Key('plate_estimate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai_consent_no')));
    await tester.pumpAndSettle();
    expect(transport.bodies, isEmpty);
  });

  testWidgets('galeria vazia convida a fotografar', (tester) async {
    await pump(tester, Scaffold(body: PlateGalleryView(deps: deps)));
    expect(find.byKey(const Key('gallery_empty')), findsOneWidget);
    expect(find.text('Fotografar prato'), findsOneWidget);
  });
}
