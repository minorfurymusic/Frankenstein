// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'dart:io';
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

  group('tacoFoods — catálogo real TACO/NEPA-UNICAMP (docs/specs/nutricao.md)', () {
    test('tem perto de 597 alimentos reais (limite frouxo: >500, algumas linhas do CSV são puladas por campo obrigatório ausente/inválido)', () {
      expect(tacoFoods.length, greaterThan(500));
    });

    test('FoodRepository.openInMemory() sem argumentos continua exatamente como antes — só o fixture, sem TACO', () {
      final repo = FoodRepository.openInMemory();
      addTearDown(repo.close);

      // Mesmos 6 itens de sempre, nenhum a mais.
      final all = repo.searchByName('', limit: 1000);
      expect(all, hasLength(fixtureFoods.length));
      expect(all.any((f) => f.id.startsWith('taco-')), isFalse);

      // Busca que bateria com item real do TACO não deve achar nada com id taco-*.
      final arroz = repo.searchByName('arroz');
      expect(arroz, hasLength(1));
      expect(arroz.first.id, 'fixture-arroz-branco-cozido');
    });

    test('seedTacoData: true traz alimentos reais do TACO, coexistindo com o fixture', () {
      final repo = FoodRepository.openInMemory(seedFixtureData: true, seedTacoData: true);
      addTearDown(repo.close);

      final arroz = repo.searchByName('arroz', limit: 100);
      final tacoArroz = arroz.where((f) => f.id.startsWith('taco-'));
      expect(tacoArroz, isNotEmpty, reason: 'busca por "arroz" deveria achar vários itens reais do TACO');
      expect(arroz.any((f) => f.id == 'fixture-arroz-branco-cozido'), isTrue,
          reason: 'o item de fixture continua presente junto do TACO');
    });

    test('round-trip: taco-1 (Arroz, integral, cozido) bate com os valores brutos do CSV de origem', () {
      final repo = FoodRepository.openInMemory(seedFixtureData: false, seedTacoData: true);
      addTearDown(repo.close);

      final food = repo.findById('taco-1');
      expect(food, isNotNull);
      expect(food!.name, 'Arroz, integral, cozido');
      expect(food.source, FoodSource.offlineCatalog);
      // Valores crus da linha 2 do CSV (numero_alimento=1):
      // energia_kcal=123.53489250000001, carboidrato_g=25.80975,
      // lipideos_g=1.0003333333333333, proteina_g=2.58825.
      expect(food.energyKcalPer100g, closeTo(123.53489250000001, 0.0001));
      expect(food.carbohydratesPer100g, closeTo(25.80975, 0.0001));
      expect(food.fatPer100g, closeTo(1.0003333333333333, 0.0001));
      expect(food.proteinPer100g, closeTo(2.58825, 0.0001));
    });

    test('sodiumPer100g é sodio_mg do CSV dividido por 1000 (taco-100, Brócolis cozido: sodio_mg=2.122)', () {
      final repo = FoodRepository.openInMemory(seedFixtureData: false, seedTacoData: true);
      addTearDown(repo.close);

      final food = repo.findById('taco-100');
      expect(food, isNotNull);
      expect(food!.name, 'Brócolis, cozido');
      expect(food.sodiumPer100g, closeTo(2.122 / 1000, 0.000001));
    });
  });

  group('FoodRepository.open — reabrir arquivo real já semeado (idempotência do reseed)', () {
    test('reabrir o mesmo arquivo com seedTacoData: true não lança (UNIQUE/PRIMARY KEY) e não duplica', () {
      final dir = Directory.systemTemp.createTempSync('nutrition_food_repo_test_');
      final dbPath = '${dir.path}/foods.sqlite3';
      addTearDown(() => dir.deleteSync(recursive: true));

      // Primeira abertura: cria o arquivo e semeia o catálogo TACO real —
      // simula a instalação/primeiro lançamento do app.
      final first = FoodRepository.open(dbPath, seedTacoData: true);
      first.close();

      // Segunda abertura do MESMO arquivo: simula o app reaberto numa
      // segunda sessão. Antes da correção, `_seedTacoData` rodava nas
      // mesmas ~578 ids `taco-*` de novo com `INSERT` puro e estourava
      // UNIQUE/PRIMARY KEY constraint aqui.
      expect(() => FoodRepository.open(dbPath, seedTacoData: true), returnsNormally);

      final reopened = FoodRepository.open(dbPath, seedTacoData: true);
      addTearDown(reopened.close);

      // Catálogo continua com o total real do TACO — nem duplicado (~1156),
      // nem vazio.
      final all = reopened.searchByName('', limit: 2000);
      final tacoOnly = all.where((f) => f.id.startsWith('taco-'));
      expect(tacoOnly.length, tacoFoods.length);

      // Item específico continua único e com os valores esperados.
      final arroz = reopened.findById('taco-1');
      expect(arroz, isNotNull);
      expect(arroz!.name, 'Arroz, integral, cozido');
    });

    test('reabrir o mesmo arquivo com seedFixtureData: true não lança e não duplica', () {
      final dir = Directory.systemTemp.createTempSync('nutrition_food_repo_fixture_test_');
      final dbPath = '${dir.path}/foods.sqlite3';
      addTearDown(() => dir.deleteSync(recursive: true));

      final first = FoodRepository.open(dbPath, seedFixtureData: true, seedTacoData: false);
      first.close();

      // Mesmo cenário do TACO acima, mas para o dataset de fixture — o
      // bug original também existia aqui, só era menos provável de bater
      // porque `seedFixtureData` é `false` por padrão em `.open()`.
      expect(
        () => FoodRepository.open(dbPath, seedFixtureData: true, seedTacoData: false),
        returnsNormally,
      );

      final reopened = FoodRepository.open(dbPath, seedFixtureData: true, seedTacoData: false);
      addTearDown(reopened.close);

      final all = reopened.searchByName('', limit: 1000);
      expect(all, hasLength(fixtureFoods.length));

      final arroz = reopened.searchByName('arroz');
      expect(arroz, hasLength(1));
      expect(arroz.first.id, 'fixture-arroz-branco-cozido');
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
