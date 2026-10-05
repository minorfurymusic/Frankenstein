import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/data/data_export.dart';
import 'package:frankstein/data/meal_plan.dart';
import 'package:frankstein/data/nutrition_store.dart';
import 'package:frankstein/documents/document_files.dart';
import 'package:frankstein/screens/nutrition/meal_plan_screens.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';

import 'support/fonts.dart';

class FakeTransport implements AiTransport {
  final List<Object> replies = [];
  final List<Map<String, dynamic>> bodies = [];
  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    bodies.add(jsonDecode(body) as Map<String, dynamic>);
    return AiHttpResponse(
      200,
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': jsonEncode(replies.removeAt(0))},
              ],
            },
          },
        ],
      }),
    );
  }
}

const planJson = {
  'name': 'Cardápio da Dra. Ana',
  'notes': 'Beber água ao longo do dia.',
  'meals': [
    {
      'meal_type': 'breakfast',
      'time': '07:30',
      'items': [
        {'description': '2 ovos mexidos', 'kcal': 150, 'protein_g': 12, 'carbs_g': 1, 'fat_g': 10},
      ],
    },
    {
      'meal_type': 'lunch',
      'items': [
        {'description': '4 colheres de sopa de arroz', 'kcal': 160},
        {'description': '1 concha de feijão', 'kcal': 100},
      ],
    },
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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: MealPlanScreen(deps: deps)));
    await tester.pumpAndSettle();
  }

  Future<void> activateAi() async {
    secrets.values['gemini_api_key'] = 'CHAVE';
    await deps.ai.load();
    deps.ai.giveConsent();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('plan_save')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('montar o próprio plano e registrar um item no diário com um toque', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('plan_create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan_add_breakfast')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plan_item_desc')), 'Tapioca com queijo');
    await tester.enterText(find.byKey(const Key('plan_item_kcal')), '280');
    await tester.enterText(find.byKey(const Key('plan_item_p')), '12');
    await tester.tap(find.byKey(const Key('plan_item_ok')));
    await tester.pumpAndSettle();
    await save(tester);

    final plan = deps.mealPlans.load()!;
    expect(plan.source, MealPlanSource.manual);
    expect(plan.meals.single.items.single.kcal, 280);
    expect(find.text('Tapioca com queijo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan_log_breakfast_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan_log_breakfast_0')));
    await tester.pumpAndSettle();
    final meals = deps.core.queryByType(HealthEventType.meal);
    expect(meals, hasLength(2));
    expect(meals.first.payload['meal_type'], 'breakfast');
    expect(deps.dayRead.totals(DateTime.now()).energyKcal, closeTo(560, 0.5));
    expect(deps.nutrition.myItems().where((f) => f.name == 'Tapioca com queijo'), hasLength(1));
  });

  testWidgets('importar do profissional: a IA lê o PDF, você confere, o documento fica guardado', (tester) async {
    await activateAi();
    transport.replies.add(planJson);
    await pump(tester);
    await tester.tap(find.byKey(const Key('plan_import')));
    await tester.pumpAndSettle();
    picker.next = PickedDocument(bytes: Uint8List.fromList(utf8.encode('%PDF plano')), name: 'plano.pdf', mimeType: 'application/pdf');
    await tester.tap(find.byKey(const Key('plan_import_pdf')));
    await tester.pumpAndSettle();
    expect(find.text('Revisar plano'), findsOneWidget);
    expect(find.text('Confira cada item antes de salvar. Calorias são estimativa.'), findsOneWidget);
    expect(find.text('2 ovos mexidos'), findsOneWidget);
    expect(find.text('plano.pdf'), findsOneWidget);
    await save(tester);

    final plan = deps.mealPlans.load()!;
    expect(plan.source, MealPlanSource.imported);
    expect(plan.name, 'Cardápio da Dra. Ana');
    expect(plan.estimated, isTrue);
    expect(plan.meals.map((m) => m.mealType.wireValue), ['breakfast', 'lunch']);
    expect(plan.meals.first.time, '07:30');
    final files = (deps.documentFiles as MemoryDocumentFileStore).files;
    expect(files.keys, [plan.attachments.single]);
    expect(buildFullExport(deps)['meal_plan']['name'], 'Cardápio da Dra. Ana');

    await tester.tap(find.byKey(const Key('plan_delete')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('plan_delete_confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(deps.mealPlans.load(), isNull);
    expect(files, isEmpty);
  });

  testWidgets('pedir sugestão à IA: vai só metas e preferências; aviso de que não é prescrição', (tester) async {
    await activateAi();
    deps.profileRepository.save(Profile(sex: BiologicalSex.female, birthDate: DateTime(1990), heightMeters: 1.65));
    deps.bodyLogger.weight(kg: 62, occurredAt: DateTime.now().toUtc(), occurredAtTzOffsetMinutes: 0);
    deps.nutrition.saveDietPreferences(const DietPreferences(tags: {'sem_lactose'}, allergies: 'amendoim'));
    transport.replies.add(planJson);
    await pump(tester);
    await tester.tap(find.byKey(const Key('plan_ai')));
    await tester.pumpAndSettle();
    final sent = jsonEncode(transport.bodies.single['contents']);
    final goals = deps.goals.goalsFor(DateTime.now())!;
    expect(sent, contains('${goals.caloriesKcal.round()} kcal'));
    expect(sent, contains('amendoim'));
    expect(sent, contains('Sem lactose'));
    expect(sent, isNot(contains('1990')));
    expect(find.byKey(const Key('plan_edit_suggestion')), findsOneWidget);
    await save(tester);
    expect(deps.mealPlans.load()!.source, MealPlanSource.ai);
    expect(find.textContaining('Isto é uma sugestão'), findsOneWidget);
    expect(find.byKey(const Key('plan_ai_disclaimer')), findsOneWidget);
  });

  testWidgets('importar sem a IA ativa: guarda o documento e você digita (nada sai do celular)', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('plan_import')));
    await tester.pumpAndSettle();
    picker.next = PickedDocument(bytes: Uint8List(8), name: 'plano.jpg', mimeType: 'image/jpeg');
    await tester.tap(find.byKey(const Key('plan_import_camera')));
    await tester.pumpAndSettle();
    expect(transport.bodies, isEmpty);
    expect(find.text('Novo plano'), findsOneWidget);
    expect(find.text('plano.jpg'), findsOneWidget);
  });
}
