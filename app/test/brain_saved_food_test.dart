import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/data/household_measures.dart';
import 'package:frankstein/screens/brain/brain_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_nutrition/nutrition.dart';

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

/// Cérebro e comida salva (decisões 18–22 de docs/DECISOES-PENDENTES.md):
/// o que está salvo é procurado no aparelho, não vai à IA.
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

  Map<String, dynamic> barcodeMeal(String code, double grams) => {
        'reply': 'Anotado.',
        'meals': [
          {
            'meal_type': 'snack',
            'items': [
              {'name': 'Produto do código $code', 'grams': grams, 'kcal': 0, 'barcode': code},
            ],
          },
        ],
      };

  testWidgets('código de barras digitado: usa o item cadastrado, não estimativa', (tester) async {
    final trakinas = deps.nutrition.createBarcodeItem(
      barcode: '7891097103841',
      name: 'Biscoito Trakinas',
      kcalPer100g: 459,
      proteinPer100g: 5.7,
      carbsPer100g: 70,
      fatPer100g: 17,
    );
    transport.replies.add(barcodeMeal('7891097103841', 63));
    await pump(tester);
    await send(tester, 'comi 6 biscoitos do 7891097103841');

    // O cadastro não vai à IA: só a mensagem.
    expect(transport.bodies.single, isNot(contains('Trakinas')));
    expect(find.text('Lanche — Biscoito Trakinas 63 g'), findsOneWidget);
    expect(find.text('289 kcal (dos seus itens salvos)'), findsOneWidget);
    expect(find.byKey(const Key('proposal_estimate')), findsNothing);

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    final item = ((deps.core.queryByType(HealthEventType.meal).single.payload['items'] as List).single as Map).cast<String, dynamic>();
    expect(item['food_id'], trakinas.id);
    expect(item['energy_kcal'], closeTo(289.2, 0.1));
  });

  testWidgets('código de barras que não está cadastrado: avisa e não inventa produto', (tester) async {
    transport.replies.add(barcodeMeal('7622210674050', 40));
    await pump(tester);
    await send(tester, 'comi 40 g do 7622210674050');

    expect(find.textContaining('O código 7622210674050 não está nos seus itens'), findsOneWidget);
    expect(find.byKey(const Key('confirmation_confirm')), findsNothing);
  });

  testWidgets('"repete o café da manhã de ontem": o app acha a refeição salva e propõe de novo', (tester) async {
    final rice = deps.foodRepository.findById('taco-1')!;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    deps.mealLogger.logMeal(
      items: [MealItemInput(foodId: rice.id, grams: 120)],
      mealType: MealType.breakfast,
      occurredAt: yesterday.toUtc(),
      occurredAtTzOffsetMinutes: yesterday.timeZoneOffset.inMinutes,
    );
    transport.replies.add({
      'reply': 'Vou repetir.',
      'repeat_meals': [
        {'meal_type': 'breakfast', 'day': 'yesterday'},
      ],
    });
    await pump(tester);
    await send(tester, 'repete o café da manhã de ontem');

    // A refeição salva não vai à IA.
    expect(transport.bodies.single, isNot(contains(rice.name)));
    expect(find.text('Café da manhã — ${rice.name} 120 g'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    final meals = deps.core.queryByType(HealthEventType.meal);
    expect(meals, hasLength(2));
    expect(((meals.last.payload['items'] as List).single as Map)['food_id'], rice.id);
  });

  testWidgets('repetir refeição que não existe: diz que não achou', (tester) async {
    transport.replies.add({
      'reply': 'Vou repetir.',
      'repeat_meals': [
        {'meal_type': 'lunch', 'day': 'today'},
      ],
    });
    await pump(tester);
    await send(tester, 'repete o almoço de hoje');
    expect(find.text('Não achei almoço salvo hoje.'), findsOneWidget);
    expect(find.byKey(const Key('confirmation_confirm')), findsNothing);
  });

  testWidgets('"o que eu comi hoje?": o app responde com o que está salvo', (tester) async {
    final rice = deps.foodRepository.findById('taco-1')!;
    final now = DateTime.now();
    deps.mealLogger.logMeal(
      items: [MealItemInput(foodId: rice.id, grams: 100)],
      mealType: MealType.lunch,
      occurredAt: now.toUtc(),
      occurredAtTzOffsetMinutes: now.timeZoneOffset.inMinutes,
    );
    transport.replies.add({
      'reply': 'Vou ver.',
      'questions': ['meals_today'],
    });
    await pump(tester);
    await send(tester, 'o que eu comi hoje?');
    expect(find.textContaining('Refeições hoje'), findsOneWidget);
    expect(find.textContaining('Almoço — ${rice.name} 100 g'), findsOneWidget);
  });

  testWidgets('bebida estimada fica em ml, com medidas de bebida, e não se repete na busca', (tester) async {
    Map<String, dynamic> coffee() => {
          'reply': 'Anotado.',
          'meals': [
            {
              'meal_type': 'breakfast',
              'items': [
                {'name': 'Café', 'grams': 200, 'liquid': true, 'kcal': 4},
              ],
            },
          ],
        };
    transport.replies
      ..add(coffee())
      ..add(coffee());
    await pump(tester);
    await send(tester, 'tomei um copo de café');
    expect(find.text('Café da manhã — Café 200 ml'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    await send(tester, 'tomei outro copo de café');
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();

    final ids = [
      for (final e in deps.core.queryByType(HealthEventType.meal)) ((e.payload['items'] as List).single as Map)['food_id'] as String,
    ];
    expect(ids, hasLength(2));
    expect(ids.toSet(), hasLength(1), reason: 'o mesmo café estimado é reaproveitado');
    final food = deps.foodRepository.findById(ids.first)!;
    expect(isLiquidFood(food), isTrue);
    expect(measuresFor(food).map((m) => m.label), contains('xícara (240 ml)'));
    expect(((deps.core.queryByType(HealthEventType.meal).first.payload['items'] as List).single as Map)['unit'], 'ml');
  });

  test('busca: estimados repetidos de antes aparecem uma vez; "Café" sozinho é bebida', () {
    for (final id in ['chat-a', 'chat-b']) {
      deps.foodRepository.insertCustomFood(
        Food(id: id, name: 'Café', source: FoodSource.custom, energyKcalPer100g: 2, proteinPer100g: 0.1, carbohydratesPer100g: 0.3, fatPer100g: 0),
      );
    }
    final found = deps.nutrition.searchFoods('café');
    expect(found.where((f) => f.name == 'Café'), hasLength(1));
    expect(found.any((f) => f.id.startsWith('taco-')), isTrue, reason: 'a TACO continua aparecendo');
    expect(isLiquidFood(found.firstWhere((f) => f.name == 'Café')), isTrue);
  });

  test('tempo esgotado tem mensagem própria, diferente de sem internet', () {
    expect(aiFailureMessage(const AiException(AiFailure.network)), contains('Sem conexão'));
    expect(aiFailureMessage(const AiException(AiFailure.timeout)), contains('demorou demais'));
  });
}
