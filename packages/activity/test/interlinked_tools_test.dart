import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';
import 'package:test/test.dart';

/// Prova que múltiplas ferramentas convivem no mesmo `BrainPipeline`,
/// com dado real passando entre camadas: F4 (`StepsRepository`) grava
/// eventos de passos; `get_steps` (F5, ligada a F4) lê esses eventos;
/// `log_meal` (demonstração do pipeline, mesma usada em
/// `packages/brain/test`) grava um evento não relacionado; nenhuma
/// interfere na outra. `packages/nutrition` continua travado por clean
/// room — `log_meal` aqui é o mesmo handler de demonstração que grava
/// direto no Health Data Core, sem lógica de nutrição nenhuma.

final _mealSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'food_id': {'type': 'string'},
          'grams': {'type': 'number'},
        },
        'required': ['food_id', 'grams'],
      },
    },
    'meal_type': {
      'enum': ['breakfast', 'lunch', 'dinner', 'snack'],
    },
  },
  'required': ['items', 'meal_type'],
};

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

ToolHandler _logMealHandler(HealthDataCore core) {
  return (params) async {
    final event = HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.meal,
      source: HealthEventSource.manual,
      occurredAt: DateTime.utc(2026, 8, 9, 12, 0),
      occurredAtTzOffsetMinutes: -180,
      recordedAt: DateTime.utc(2026, 8, 9, 12, 0),
      payload: params,
      confidence: 1.0,
    );
    core.insertEvent(event);
    return ToolResult.ok({'event_id': event.id});
  };
}

void main() {
  test(
      'get_steps (dado real do F4) e log_meal convivem no mesmo BrainPipeline, sem interferência',
      () async {
    final core = HealthDataCore.openInMemory();
    addTearDown(core.close);

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
      ToolSpec(
        name: 'log_meal',
        description: 'Registra uma refeição no diário alimentar',
        write: true,
        confirm: true,
        module: 'nutrition',
        parametersSchema: _mealSchema,
      ),
      _logMealHandler(core),
    );

    final pipeline = BrainPipeline(
      registry: registry,
      callers: [_sharedRouter()],
      confirmationGate: _AlwaysConfirm(),
    );

    final stepsResult = await pipeline.handle('quantos passos eu dei em 2026-08-09?');
    expect(stepsResult.outcome, PipelineOutcome.executed);
    expect(stepsResult.toolResult!.data!['total_steps'], 4500);

    final mealResult = await pipeline.handle(
      'registrar refeição lunch: arroz-branco 150g',
    );
    expect(mealResult.outcome, PipelineOutcome.executed);

    // A refeição não mudou o total de passos, e vice-versa — os dois
    // tipos de HealthEvent convivem no mesmo Core sem se misturar.
    final stepsAgain = await pipeline.handle('quantos passos eu dei em 2026-08-09?');
    expect(stepsAgain.toolResult!.data!['total_steps'], 4500);
    expect(core.queryByType(HealthEventType.meal), hasLength(1));
    expect(core.queryByType(HealthEventType.steps), hasLength(1));
  });
}
