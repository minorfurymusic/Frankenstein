// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'dart:typed_data';

import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';
import 'package:test/test.dart';

void main() {
  group('FoodRepository — catálogo local (dataset de fixture)', () {
    test('abre em memória já populado pelo dataset de fixture', () {
      final repo = FoodRepository.openInMemory();
      addTearDown(repo.close);

      expect(fixtureFoods, isNotEmpty);
      for (final food in fixtureFoods) {
        expect(repo.findById(food.id), isNotNull);
      }
    });

    test('findByBarcode encontra um alimento do fixture pelo código', () {
      final repo = FoodRepository.openInMemory();
      addTearDown(repo.close);

      final found = repo.findByBarcode('7891000000013');
      expect(found, isNotNull);
      expect(found!.name, 'Arroz branco cozido');
      expect(found.source, FoodSource.offlineCatalog);
    });

    test('findByBarcode retorna null para código desconhecido', () {
      final repo = FoodRepository.openInMemory();
      addTearDown(repo.close);

      expect(repo.findByBarcode('0000000000000'), isNull);
    });

    test('searchByName é case-insensitive e por substring', () {
      final repo = FoodRepository.openInMemory();
      addTearDown(repo.close);

      final results = repo.searchByName('frango');
      expect(results, hasLength(1));
      expect(results.first.name, 'Peito de frango grelhado');

      final upper = repo.searchByName('FRANGO');
      expect(upper, hasLength(1));
    });

    test('insertCustomFood cadastra um item personalizado (adição rápida)', () {
      final repo = FoodRepository.openInMemory();
      addTearDown(repo.close);

      final custom = Food(
        id: 'custom-vitamina-banana',
        name: 'Vitamina de banana (caseira)',
        source: FoodSource.custom,
        energyKcalPer100g: 90,
        carbohydratesPer100g: 15,
        fatPer100g: 2,
        proteinPer100g: 3,
      );
      repo.insertCustomFood(custom);

      final back = repo.findById('custom-vitamina-banana');
      expect(back, isNotNull);
      expect(back!.source, FoodSource.custom);
    });

    test('insertCustomFood rejeita source != custom', () {
      final repo = FoodRepository.openInMemory();
      addTearDown(repo.close);

      final naoCustom = Food(
        id: 'nao-deveria-entrar',
        name: 'Item com source errado',
        source: FoodSource.offlineCatalog,
        energyKcalPer100g: 1,
        carbohydratesPer100g: 1,
        fatPer100g: 1,
        proteinPer100g: 1,
      );
      expect(() => repo.insertCustomFood(naoCustom), throwsA(isA<InvalidFoodSourceException>()));
    });
  });

  group('MealLogger — grava HealthEvent tipo meal', () {
    test('calcula macros totais para um item e grava evento com payload completo', () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);
      final foodRepo = FoodRepository.openInMemory();
      addTearDown(foodRepo.close);
      final logger = MealLogger(foodRepository: foodRepo, core: core);

      // Arroz branco cozido: 130 kcal / 100g. 150g => 195 kcal.
      final event = logger.logMeal(
        items: [MealItemInput(foodId: 'fixture-arroz-branco-cozido', grams: 150)],
        mealType: MealType.lunch,
        occurredAt: DateTime.utc(2026, 8, 10, 12, 0),
        occurredAtTzOffsetMinutes: -180,
      );

      expect(event.type, HealthEventType.meal);
      expect(event.source, HealthEventSource.manual);
      expect(event.payload['meal_type'], 'lunch');

      final totals = event.payload['totals'] as Map<String, dynamic>;
      expect(totals['energy_kcal'], closeTo(195.0, 0.001));
      expect(totals['carbohydrates_g'], closeTo(42.3, 0.001));

      final items = event.payload['items'] as List;
      expect(items, hasLength(1));
      final item = items.first as Map<String, dynamic>;
      expect(item['food_id'], 'fixture-arroz-branco-cozido');
      expect(item['grams'], 150);
      expect(item['unit'], 'g');
      expect(item['source'], 'offline_catalog');

      // O evento realmente está no Health Data Core, não só no retorno.
      final back = core.getById(event.id);
      expect(back, isNotNull);
    });

    test('soma macros de múltiplos itens numa mesma refeição', () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);
      final foodRepo = FoodRepository.openInMemory();
      addTearDown(foodRepo.close);
      final logger = MealLogger(foodRepository: foodRepo, core: core);

      final event = logger.logMeal(
        items: [
          MealItemInput(foodId: 'fixture-arroz-branco-cozido', grams: 100), // 130 kcal
          MealItemInput(foodId: 'fixture-feijao-carioca-cozido', grams: 100), // 76 kcal
        ],
        mealType: MealType.dinner,
        occurredAt: DateTime.utc(2026, 8, 10, 19, 0),
        occurredAtTzOffsetMinutes: -180,
      );

      final totals = event.payload['totals'] as Map<String, dynamic>;
      expect(totals['energy_kcal'], closeTo(206.0, 0.001));
    });

    test('food_id desconhecido lança FoodNotFoundException e não grava nada', () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);
      final foodRepo = FoodRepository.openInMemory();
      addTearDown(foodRepo.close);
      final logger = MealLogger(foodRepository: foodRepo, core: core);

      expect(
        () => logger.logMeal(
          items: [MealItemInput(foodId: 'nao-existe', grams: 100)],
          mealType: MealType.snack,
          occurredAt: DateTime.utc(2026, 8, 10, 16, 0),
          occurredAtTzOffsetMinutes: -180,
        ),
        throwsA(isA<FoodNotFoundException>()),
      );
      expect(core.queryByType(HealthEventType.meal), isEmpty);
    });

    test('occurredAt precisa estar em UTC', () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);
      final foodRepo = FoodRepository.openInMemory();
      addTearDown(foodRepo.close);
      final logger = MealLogger(foodRepository: foodRepo, core: core);

      expect(
        () => logger.logMeal(
          items: [MealItemInput(foodId: 'fixture-arroz-branco-cozido', grams: 100)],
          mealType: MealType.snack,
          occurredAt: DateTime(2026, 8, 10, 16, 0), // local, não UTC
          occurredAtTzOffsetMinutes: -180,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('BarcodeDecoder — interface abstrata, fixture para teste', () {
    test('FixtureBarcodeDecoder decodifica uma imagem registrada', () async {
      final decoder = FixtureBarcodeDecoder();
      final fakeImage = Uint8List.fromList([1, 2, 3, 4]);
      decoder.registerImage(fakeImage, '7891000000013');

      final result = await decoder.decodeImage(fakeImage);
      expect(result, '7891000000013');
    });

    test('FixtureBarcodeDecoder retorna null para imagem não registrada', () async {
      final decoder = FixtureBarcodeDecoder();
      final result = await decoder.decodeImage(Uint8List.fromList([9, 9, 9]));
      expect(result, isNull);
    });

    test(
        'fluxo "registrar por código de barras": decodifica -> acha no catálogo -> registra refeição',
        () async {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);
      final foodRepo = FoodRepository.openInMemory();
      addTearDown(foodRepo.close);
      final logger = MealLogger(foodRepository: foodRepo, core: core);
      final decoder = FixtureBarcodeDecoder();

      final scannedImage = Uint8List.fromList([5, 5, 5]);
      decoder.registerImage(scannedImage, '7891000000051'); // frango grelhado

      final barcode = await decoder.decodeImage(scannedImage);
      expect(barcode, isNotNull);

      final food = foodRepo.findByBarcode(barcode!);
      expect(food, isNotNull);

      final event = logger.logMeal(
        items: [MealItemInput(foodId: food!.id, grams: 200, inputMethod: MealItemInputMethod.barcode)],
        mealType: MealType.lunch,
        occurredAt: DateTime.utc(2026, 8, 10, 12, 30),
        occurredAtTzOffsetMinutes: -180,
      );

      final items = event.payload['items'] as List;
      final item = items.first as Map<String, dynamic>;
      expect(item['input_method'], 'barcode');
      expect(item['barcode'], '7891000000051');
      // Peito de frango grelhado: 159 kcal/100g * 200g = 318 kcal.
      expect(item['energy_kcal'], closeTo(318.0, 0.001));
    });
  });

  group('log_meal — ferramenta real do cérebro', () {
    test('logMealSpec/logMealHandler executam via ToolRegistry com validação de schema', () async {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);
      final foodRepo = FoodRepository.openInMemory();
      addTearDown(foodRepo.close);
      final logger = MealLogger(foodRepository: foodRepo, core: core);

      final registry = ToolRegistry();
      registry.register(logMealSpec(), logMealHandler(logger, tzOffsetMinutesProvider: () => -180));

      final result = await registry.execute('log_meal', {
        'items': [
          {'food_id': 'fixture-banana-prata', 'grams': 120},
        ],
        'meal_type': 'snack',
        'at': '2026-08-10T15:00:00Z',
      });

      expect(result.success, isTrue);
      expect(result.data!['event_id'], isNotNull);
      final totals = result.data!['totals'] as Map<String, dynamic>;
      // Banana prata: 98 kcal/100g * 120g = 117.6 kcal.
      expect(totals['energy_kcal'], closeTo(117.6, 0.001));
      expect(core.queryByType(HealthEventType.meal), hasLength(1));
    });

    test('ToolRegistry.execute rejeita parâmetros que não batem no schema (meal_type inválido)', () async {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);
      final foodRepo = FoodRepository.openInMemory();
      addTearDown(foodRepo.close);
      final logger = MealLogger(foodRepository: foodRepo, core: core);

      final registry = ToolRegistry();
      registry.register(logMealSpec(), logMealHandler(logger, tzOffsetMinutesProvider: () => -180));

      expect(
        () => registry.execute('log_meal', {
          'items': [
            {'food_id': 'fixture-banana-prata', 'grams': 120},
          ],
          'meal_type': 'brunch', // não é um dos 4 valores aceitos
        }),
        throwsA(isA<ToolValidationException>()),
      );
      expect(core.queryByType(HealthEventType.meal), isEmpty);
    });

    test('food_id desconhecido volta como ToolResult.failure, não exceção não tratada', () async {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);
      final foodRepo = FoodRepository.openInMemory();
      addTearDown(foodRepo.close);
      final logger = MealLogger(foodRepository: foodRepo, core: core);

      final registry = ToolRegistry();
      registry.register(logMealSpec(), logMealHandler(logger, tzOffsetMinutesProvider: () => -180));

      final result = await registry.execute('log_meal', {
        'items': [
          {'food_id': 'fantasma', 'grams': 50},
        ],
        'meal_type': 'breakfast',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('fantasma'));
    });

    test(
        'prova de ponta a ponta: BrainPipeline com roteador determinístico chama log_meal real e grava HealthEvent',
        () async {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);
      final foodRepo = FoodRepository.openInMemory();
      addTearDown(foodRepo.close);
      final logger = MealLogger(foodRepository: foodRepo, core: core);

      final registry = ToolRegistry();
      registry.register(logMealSpec(), logMealHandler(logger, tzOffsetMinutesProvider: () => -180));

      // Roteador de teste próprio deste ciclo — não copiado de nenhum
      // roteador existente; só reconhece uma frase fixa em português para
      // provar que o pipeline chega até o handler real.
      final pattern = RegExp(
        r'^comi (\d+(?:\.\d+)?)g de ([a-z0-9\-]+) no (café da manhã|almoço|jantar|lanche)$',
        caseSensitive: false,
      );
      const mealTypeByPortuguese = {
        'café da manhã': 'breakfast',
        'almoço': 'lunch',
        'jantar': 'dinner',
        'lanche': 'snack',
      };
      final router = DeterministicRouter([
        RouterRule(
          toolName: 'log_meal',
          pattern: pattern,
          extractParams: (m) => {
            'items': [
              {'food_id': m.group(2)!, 'grams': double.parse(m.group(1)!)},
            ],
            'meal_type': mealTypeByPortuguese[m.group(3)!.toLowerCase()],
          },
        ),
      ]);

      final pipeline = BrainPipeline(
        registry: registry,
        callers: [router],
        confirmationGate: _AlwaysConfirm(),
      );

      final result = await pipeline.handle('comi 100g de fixture-ovo-cozido no café da manhã');

      expect(result.outcome, PipelineOutcome.executed);
      expect(result.toolResult!.success, isTrue);
      final totals = result.toolResult!.data!['totals'] as Map<String, dynamic>;
      // Ovo cozido: 146 kcal/100g * 100g = 146 kcal.
      expect(totals['energy_kcal'], closeTo(146.0, 0.001));
      expect(core.queryByType(HealthEventType.meal), hasLength(1));
    });
  });

  group('search_food — ferramenta de leitura do cérebro', () {
    test('searchFoodSpec() é uma ferramenta de leitura (write:false, confirm:false)', () {
      final spec = searchFoodSpec();
      expect(spec.name, 'search_food');
      expect(spec.write, isFalse);
      expect(spec.confirm, isFalse);
      expect(spec.module, 'nutrition');
    });

    test('encontra alimentos do fixture por substring case-insensitive via ToolRegistry', () async {
      final foodRepo = FoodRepository.openInMemory();
      addTearDown(foodRepo.close);

      final registry = ToolRegistry();
      registry.register(searchFoodSpec(), searchFoodHandler(foodRepo));

      final result = await registry.execute('search_food', {'query': 'FRANGO'});

      expect(result.success, isTrue);
      final results = result.data!['results'] as List;
      expect(results, hasLength(1));
      final food = results.first as Map<String, dynamic>;
      expect(food['name'], 'Peito de frango grelhado');
      expect(food['id'], isNotNull);
      expect(food.containsKey('energy_kcal_100g'), isTrue);
    });

    test('busca sem correspondência devolve results vazio, não falha', () async {
      final foodRepo = FoodRepository.openInMemory();
      addTearDown(foodRepo.close);

      final registry = ToolRegistry();
      registry.register(searchFoodSpec(), searchFoodHandler(foodRepo));

      final result = await registry.execute('search_food', {'query': 'inexistente-xyz'});

      expect(result.success, isTrue);
      expect(result.data!['results'], isEmpty);
    });
  });
}

class _AlwaysConfirm implements ConfirmationGate {
  @override
  Future<bool> confirm(ToolSpec spec, Map<String, dynamic> params) async => true;
}
