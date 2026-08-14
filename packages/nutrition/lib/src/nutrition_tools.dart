// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:frankstein_tool_registry/tool_registry.dart';

import 'food_repository.dart';
import 'meal.dart';
import 'meal_logger.dart';

/// Schema de `log_meal` — mesmo contrato documentado em
/// `docs/ARQUITETURA.md:60-79`.
final Map<String, dynamic> logMealSchema = {
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
    'at': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['items', 'meal_type'],
};

/// `log_meal` — ferramenta de escrita, uma das mínimas do MVP
/// (`docs/ARQUITETURA.md:81-82`). Registra uma refeição real via
/// [MealLogger], mesmo padrão de `packages/activity/lib/src/activity_tools.dart`
/// (`getStepsSpec`/`getStepsHandler`): uma função que devolve o `ToolSpec`,
/// outra que devolve o `ToolHandler` fechado sobre a dependência real.
ToolSpec logMealSpec() => ToolSpec(
      name: 'log_meal',
      description: 'Registra uma refeição no diário alimentar',
      write: true,
      confirm: true,
      module: 'nutrition',
      parametersSchema: logMealSchema,
    );

/// [tzOffsetMinutesProvider] existe porque o contrato JSON de `log_meal`
/// (`docs/ARQUITETURA.md:60-79`) não carrega fuso horário — só `at`
/// (instante). `HealthEvent.occurredAtTzOffsetMinutes` é obrigatório
/// (`.claude/rules/00-inviolaveis.md`: "Timestamps em UTC, com timezone
/// gravado à parte") e precisa vir de quem conhece o fuso do aparelho no
/// momento do registro — não dá pra derivar de `at` sozinho. É uma
/// função, não um valor fixo, porque o fuso do aparelho pode mudar
/// (viagem) entre chamadas.
ToolHandler logMealHandler(
  MealLogger logger, {
  required int Function() tzOffsetMinutesProvider,
}) {
  return (params) async {
    try {
      final itemsRaw = params['items'] as List;
      final items = itemsRaw.map((raw) {
        final map = raw as Map<String, dynamic>;
        return MealItemInput(
          foodId: map['food_id'] as String,
          grams: (map['grams'] as num).toDouble(),
        );
      }).toList();

      final mealType = MealType.fromWireValue(params['meal_type'] as String);
      final atRaw = params['at'] as String?;
      final occurredAt = atRaw != null ? DateTime.parse(atRaw).toUtc() : DateTime.now().toUtc();

      final event = logger.logMeal(
        items: items,
        mealType: mealType,
        occurredAt: occurredAt,
        occurredAtTzOffsetMinutes: tzOffsetMinutesProvider(),
      );

      return ToolResult.ok({
        'event_id': event.id,
        'meal_type': event.payload['meal_type'],
        'totals': event.payload['totals'],
      });
    } on FoodNotFoundException catch (e) {
      return ToolResult.failure(e.toString());
    }
  };
}

/// Schema de `search_food` — busca por nome no catálogo local
/// (`docs/specs/nutricao.md`, tela "Adicionar alimento": "busca por
/// nome").
final Map<String, dynamic> searchFoodSchema = {
  'type': 'object',
  'properties': {
    'query': {'type': 'string'},
    'limit': {'type': 'integer'},
  },
  'required': ['query'],
};

/// `search_food` — ferramenta de leitura, mesmo padrão de `get_workout_plan`
/// (`packages/activity/lib/src/activity_tools.dart`) e de `logMealSpec`
/// acima: só que sem escrita nem confirmação, porque busca não altera
/// nada no Health Data Core.
ToolSpec searchFoodSpec() => ToolSpec(
      name: 'search_food',
      description: 'Busca alimentos no catálogo local pelo nome',
      write: false,
      confirm: false,
      module: 'nutrition',
      parametersSchema: searchFoodSchema,
    );

/// Fechado sobre [FoodRepository.searchByName] — wrapper fino, mesma
/// lógica de `logMealHandler` acima: uma função que devolve o
/// `ToolHandler`.
ToolHandler searchFoodHandler(FoodRepository repository) {
  return (params) async {
    final query = params['query'] as String;
    final limit = params['limit'] as int?;

    final results = repository.searchByName(query, limit: limit ?? 20);

    return ToolResult.ok({
      'results': results
          .map((food) => {
                'id': food.id,
                'name': food.name,
                'brand': food.brand,
                'barcode': food.barcode,
                'energy_kcal_100g': food.energyKcalPer100g,
              })
          .toList(),
    });
  };
}
