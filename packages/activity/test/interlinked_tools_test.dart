import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';
import 'package:test/test.dart';

/// Prova que múltiplas ferramentas convivem no mesmo `BrainPipeline`,
/// com dado real passando entre camadas: F4 (`StepsRepository`) grava
/// eventos de passos; `get_steps` (F5, ligada a F4) lê esses eventos;
/// `log_meal` (F6, `packages/nutrition` — não é mais demonstração, é o
/// `MealLogger`/`FoodRepository` reais) grava um evento de refeição de
/// verdade, calculando macros a partir do catálogo. Nenhuma interfere na
/// outra.
final _logMealPattern = RegExp(
  r'^registrar refeição (breakfast|lunch|dinner|snack): (.+)$',
  caseSensitive: false,
);
final _itemPattern = RegExp(r'([a-z0-9\-]+)\s+(\d+(?:\.\d+)?)g');

final _getStepsPattern = RegExp(
  r'^quantos passos eu dei em (\d{4}-\d{2}-\d{2})\??$',
  caseSensitive: false,
);

DeterministicRouter _sharedRouter() => DeterministicRouter([
      RouterRule(
        toolName: 'log_meal',
        pattern: _logMealPattern,
        extractParams: (m) {
          final items = _itemPattern.allMatches(m.group(2)!).map((im) => {
                'food_id': im.group(1),
                'grams': double.parse(im.group(2)!),
              }).toList();
          return {'items': items, 'meal_type': m.group(1)!.toLowerCase()};
        },
      ),
      RouterRule(
        toolName: 'get_steps',
        pattern: _getStepsPattern,
        extractParams: (m) => {'date': m.group(1)},
      ),
    ]);

class _AlwaysConfirm implements ConfirmationGate {
  @override
  Future<bool> confirm(ToolSpec spec, Map<String, dynamic> params) async => true;
}

void main() {
  test(
      'get_steps (F4) e log_meal real (F6) convivem no mesmo BrainPipeline, sem interferência',
      () async {
    final core = HealthDataCore.openInMemory();
    addTearDown(core.close);
    final foodRepository = FoodRepository.openInMemory(seedFixtureData: true);
    addTearDown(foodRepository.close);
    final mealLogger = MealLogger(foodRepository: foodRepository, core: core);

    // F4: passos de verdade, agregados pelo StepsRepository — não um
    // HealthEvent escrito à mão só para o teste.
    final steps = StepsRepository(core: core, deviceId: 'device-1');
    steps.recordSample(StepsSample(
      deviceId: 'device-1',
      timestampUtc: DateTime.utc(2026, 8, 9, 7, 0),
      cumulativeSteps: 2000,
      tzOffsetMinutes: -180,
    ));
    steps.recordSample(StepsSample(
      deviceId: 'device-1',
      timestampUtc: DateTime.utc(2026, 8, 9, 12, 0),
      cumulativeSteps: 6500,
      tzOffsetMinutes: -180,
    ));
    steps.flush(at: DateTime.utc(2026, 8, 9, 12, 0, 1), tzOffsetMinutes: -180);

    final registry = ToolRegistry();
    registry.register(getStepsSpec(), getStepsHandler(core));
    registry.register(
      logMealSpec(),
      logMealHandler(mealLogger, tzOffsetMinutesProvider: () => -180),
    );

    final pipeline = BrainPipeline(
      registry: registry,
      callers: [_sharedRouter()],
      confirmationGate: _AlwaysConfirm(),
    );

    final stepsResult = await pipeline.handle('quantos passos eu dei em 2026-08-09?');
    expect(stepsResult.outcome, PipelineOutcome.executed);
    expect(stepsResult.toolResult!.data!['total_steps'], 4500);

    // "fixture-arroz-branco-cozido" é um id real do dataset de fixture
    // (packages/nutrition/lib/src/food_fixture_dataset.dart) — o handler
    // real de log_meal busca no FoodRepository de verdade, calcula macros
    // a partir dos dados de 100g do alimento, não aceita qualquer string.
    final mealResult = await pipeline.handle(
      'registrar refeição lunch: fixture-arroz-branco-cozido 150g',
    );
    expect(mealResult.outcome, PipelineOutcome.executed);
    expect(mealResult.toolResult!.success, isTrue);
    final totals = mealResult.toolResult!.data!['totals'] as Map;
    // 150g de arroz branco cozido (130 kcal/100g no fixture) = 195 kcal.
    expect(totals['energy_kcal'], closeTo(195.0, 0.01));

    // Alimento fora do catálogo é rejeitado, não silenciosamente aceito.
    final unknownFoodResult = await pipeline.handle(
      'registrar refeição dinner: alimento-inexistente 100g',
    );
    expect(unknownFoodResult.outcome, PipelineOutcome.executed);
    expect(unknownFoodResult.toolResult!.success, isFalse);

    // A refeição não mudou o total de passos, e vice-versa — os dois
    // tipos de HealthEvent convivem no mesmo Core sem se misturar.
    final stepsAgain = await pipeline.handle('quantos passos eu dei em 2026-08-09?');
    expect(stepsAgain.toolResult!.data!['total_steps'], 4500);
    expect(core.queryByType(HealthEventType.meal), hasLength(1));
    expect(core.queryByType(HealthEventType.steps), hasLength(1));
  });
}
