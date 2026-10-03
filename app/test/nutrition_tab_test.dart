// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/data/nutrition_store.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_profile/profile.dart';

import 'support/fonts.dart';

void main() {
  setUpAll(loadFigtree);

  late AppDependencies deps;
  late Widget app;

  setUp(() {
    final navigatorKey = GlobalKey<NavigatorState>();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(navigatorKey),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
    );
    app = FrankstitApp(dependencies: deps, navigatorKey: navigatorKey);
  });
  tearDown(() => deps.close());

  Future<void> openNutrition(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav_nutricao')));
    await tester.pumpAndSettle();
  }

  void giveProfile() {
    deps.profileRepository.save(Profile(sex: BiologicalSex.male, birthDate: DateTime(1990), heightMeters: 1.75));
    deps.bodyLogger.weight(kg: 70, occurredAt: DateTime.now().toUtc(), occurredAtTzOffsetMinutes: 0);
  }

  List<HealthEvent> meals() => deps.core.queryByType(HealthEventType.meal);

  testWidgets('sem perfil: mostra consumo e pede o perfil; botão de água grava', (tester) async {
    await openNutrition(tester);
    expect(find.text('Preencha o perfil para ver suas metas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('water_300')));
    await tester.pumpAndSettle();
    final water = deps.core.queryByType(HealthEventType.water).single;
    expect(water.payload['amount_ml'], 300);
    expect(find.textContaining('300 ml', findRichText: true), findsWidgets);
  });

  testWidgets('com perfil: anel mostra kcal restantes e barras de macro e fibra', (tester) async {
    giveProfile();
    await openNutrition(tester);
    final goals = deps.goals.goalsFor(DateTime.now())!;
    expect(find.text('kcal restantes'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('kcal_center'))).data, isNot('0'));
    expect(goals.caloriesKcal, greaterThan(0));
    expect(find.text('Fibra'), findsOneWidget);
  });

  testWidgets('buscar arroz, escolher 150 g no café da manhã grava a refeição', (tester) async {
    await openNutrition(tester);
    await tester.tap(find.byKey(const Key('meal_add_breakfast')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food_search')), 'arroz');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('result_0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food_grams')), '150');
    await tester.pump();
    await tester.tap(find.byKey(const Key('food_add')));
    await tester.pumpAndSettle();

    final e = meals().single;
    expect(e.payload['meal_type'], 'breakfast');
    final item = (e.payload['items'] as List).single as Map<String, dynamic>;
    expect(item['grams'], 150);
    expect((item['name'] as String).toLowerCase(), contains('arroz'));
    expect(find.text(item['name'] as String), findsOneWidget); // aparece no Hoje
  });

  testWidgets('adição rápida: nome + kcal vira item próprio e registro de 1 porção', (tester) async {
    await openNutrition(tester);
    await tester.tap(find.byKey(const Key('meal_add_lunch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_quick')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quick_name')), 'Marmita do trabalho');
    await tester.enterText(find.byKey(const Key('quick_kcal')), '520');
    await tester.tap(find.byKey(const Key('quick_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food_add')));
    await tester.pumpAndSettle();

    final totals = meals().single.payload['totals'] as Map<String, dynamic>;
    expect(totals['energy_kcal'], closeTo(520, 1e-9));
    expect(deps.nutrition.myItems().single.name, 'Marmita do trabalho');
  });

  testWidgets('código de barras digitado encontra o alimento do catálogo', (tester) async {
    await openNutrition(tester);
    await tester.tap(find.byKey(const Key('meal_add_snack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_barcode')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('barcode_input')), '7891000000075');
    await tester.tap(find.byKey(const Key('barcode_ok')));
    await tester.pumpAndSettle();
    expect(find.text('Banana prata'), findsOneWidget);
    await tester.tap(find.byKey(const Key('food_add')));
    await tester.pumpAndSettle();
    final item = (meals().single.payload['items'] as List).single as Map<String, dynamic>;
    expect(item['input_method'], 'barcode');
  });

  testWidgets('fechar o dia: dia vazio mantendo o peso não bate a meta', (tester) async {
    giveProfile();
    await openNutrition(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('close_day')),
      300,
      scrollable: find.descendant(of: find.byKey(const Key('nutrition_today')), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.byKey(const Key('close_day')));
    await tester.pumpAndSettle();
    expect(find.text('Dia fechado'), findsOneWidget);
    expect(find.textContaining('Meta não batida'), findsOneWidget);
    expect(deps.nutrition.isClosedManually(DateTime.now()), isTrue);
  });

  testWidgets('Diário pinta o dia de hoje quando há refeição', (tester) async {
    giveProfile();
    final banana = deps.foodRepository.findByBarcode('7891000000075')!;
    deps.mealLogger.logMeal(
      items: [MealItemInput(foodId: banana.id, grams: 100)],
      mealType: MealType.snack,
      occurredAt: DateTime.now().toUtc(),
      occurredAtTzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
    await openNutrition(tester);
    await tester.tap(find.text('Diário'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fora da meta (1)'), findsOneWidget); // 1 banana < meta de manter
    await tester.tap(find.byKey(Key('diary_day_${DateTime.now().day}')));
    await tester.pumpAndSettle();
    expect(find.text('Banana prata'), findsOneWidget);
  });

  group('NutritionStore', () {
    test('receita soma ingredientes e grava valores por 100 g', () {
      final arroz = deps.foodRepository.findByBarcode('7891000000013')!;
      final feijao = deps.foodRepository.findByBarcode('7891000000037')!;
      final r = deps.nutrition.createRecipe(
        name: 'Arroz com feijão',
        servings: 2,
        ingredients: [RecipeIngredient(arroz.id, 200), RecipeIngredient(feijao.id, 100)],
      );
      final food = deps.foodRepository.findById(r.foodId)!;
      final kcal = arroz.energyKcalPer100g * 2 + feijao.energyKcalPer100g;
      expect(food.energyKcalPer100g, closeTo(kcal / 3, 1e-9));
      expect(r.servingGrams, 150);
      expect(deps.nutrition.recipes().single.name, 'Arroz com feijão');
    });

    test('recentes vêm do mais novo, sem repetir; favoritos alternam', () {
      final banana = deps.foodRepository.findByBarcode('7891000000075')!;
      final ovo = deps.foodRepository.findByBarcode('7891000000099')!;
      final now = DateTime.now().toUtc();
      for (final (f, m) in [(banana, 30), (ovo, 20), (banana, 10)]) {
        deps.mealLogger.logMeal(
          items: [MealItemInput(foodId: f.id, grams: 100)],
          mealType: MealType.snack,
          occurredAt: now.subtract(Duration(minutes: m)),
          occurredAtTzOffsetMinutes: 0,
        );
      }
      expect(deps.nutrition.recentFoods().map((f) => f.id), [banana.id, ovo.id]);
      deps.nutrition.toggleFavorite(ovo.id);
      expect(deps.nutrition.favoriteFoods().single.id, ovo.id);
      deps.nutrition.toggleFavorite(ovo.id);
      expect(deps.nutrition.favoriteFoods(), isEmpty);
    });

    test('preferências de dieta guardam e voltam', () {
      deps.nutrition.saveDietPreferences(const DietPreferences(tags: {'vegano'}, allergies: 'amendoim'));
      final p = deps.nutrition.dietPreferences();
      expect(p.tags, {'vegano'});
      expect(p.allergies, 'amendoim');
    });
  });
}
