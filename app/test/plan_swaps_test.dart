import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/ai/plan_swaps.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/data/meal_plan.dart';
import 'package:frankstein/screens/brain/brain_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_ai/ai.dart';
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
    deps.mealPlans.save(MealPlan(
      name: 'Plano da nutri',
      source: MealPlanSource.imported,
      createdAt: DateTime(2026, 10, 1),
      meals: [
        MealPlanMeal(mealType: MealType.breakfast, items: [MealPlanItem(description: 'Pão integral 2 fatias', kcal: 140)]),
        MealPlanMeal(mealType: MealType.dinner, items: [
          MealPlanItem(description: 'Arroz 100 g', kcal: 128, proteinGrams: 2.5, carbsGrams: 28, fatGrams: 0.2),
          MealPlanItem(description: '2 ovos fritos', kcal: 180, proteinGrams: 12, carbsGrams: 1, fatGrams: 14),
        ]),
      ],
    ));
    deps.workoutRepository.savePlan(WorkoutPlan(id: 'a', name: 'Treino A', exercises: [
      PlannedExercise(exerciseId: 'supino-reto', exerciseName: 'Supino reto', targetSets: 3, targetReps: 10, targetLoadKg: 60),
    ]));
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

  test('"ovo" acha "2 ovos fritos"; "supino" acha "Supino reto"', () {
    expect(mentions('2 ovos fritos', 'ovo'), isTrue);
    expect(mentions('Supino reto', 'supino'), isTrue);
    expect(mentions('Arroz 100 g', 'ovo'), isFalse);
  });

  testWidgets('"não aguento mais ovo": a IA calcula o equivalente, vira cartão e o plano muda ao confirmar', (tester) async {
    transport.replies
      ..add({
        'reply': 'Vamos trocar.',
        'plan_swaps': [
          {'plan': 'meal', 'item': 'ovo'},
        ],
      })
      ..add({'description': 'Bife grelhado 80 g', 'kcal': 175, 'protein_g': 24, 'carbs_g': 0, 'fat_g': 8});
    await pump(tester);
    await send(tester, 'não aguento mais comer ovo');

    // Só o item a trocar vai na segunda chamada; o plano inteiro, não.
    final second = transport.bodies[1];
    expect(second, contains('2 ovos fritos'));
    expect(second, isNot(contains('Pão integral')));
    expect(find.text('Trocar no plano — Jantar'), findsOneWidget);
    expect(find.textContaining('→ Bife grelhado 80 g (175 kcal, 24 g proteína)'), findsOneWidget);
    expect(find.textContaining('Avise seu nutricionista'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    final items = deps.mealPlans.load()!.mealsOf(MealType.dinner).single.items;
    expect(items.map((i) => i.description), ['Arroz 100 g', 'Bife grelhado 80 g']);
  });

  testWidgets('troca que mudaria muito as calorias não vira cartão', (tester) async {
    transport.replies
      ..add({
        'reply': 'Ok.',
        'plan_swaps': [
          {'plan': 'meal', 'item': 'ovo', 'replacement': 'pizza'},
        ],
      })
      ..add({'description': 'Pizza 2 fatias', 'kcal': 540, 'protein_g': 22, 'carbs_g': 60, 'fat_g': 22});
    await pump(tester);
    await send(tester, 'troca o ovo da janta por pizza');
    expect(find.textContaining('mudaria muito as calorias'), findsOneWidget);
    expect(find.byKey(const Key('confirmation_confirm')), findsNothing);
  });

  testWidgets('exercício: sem dizer por qual, oferece os do mesmo músculo; dizendo, vira cartão', (tester) async {
    transport.replies.add({
      'reply': 'Ok.',
      'plan_swaps': [
        {'plan': 'workout', 'item': 'supino'},
      ],
    });
    await pump(tester);
    await send(tester, 'enjoei do supino');
    expect(find.textContaining('dá para trocar por'), findsOneWidget);
    expect(find.byKey(const Key('brain_reply_Troca Supino reto por Crucifixo')), findsOneWidget);

    transport.replies.add({
      'reply': 'Ok.',
      'plan_swaps': [
        {'plan': 'workout', 'item': 'Supino reto', 'replacement': 'Crucifixo'},
      ],
    });
    await tester.tap(find.byKey(const Key('brain_reply_Troca Supino reto por Crucifixo')));
    await tester.pumpAndSettle();
    expect(find.text('Trocar na ficha — Treino A'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    final ex = deps.workoutRepository.findPlanById('a')!.exercises.single;
    expect(ex.exerciseName, 'Crucifixo');
    expect(ex.targetSets, 3);
    expect(ex.targetLoadKg, isNull);
  });
}
