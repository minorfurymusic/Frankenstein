// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:frankstein_health_core/health_core.dart';

import 'food_repository.dart';
import 'meal.dart';

/// Lançada quando um item de [MealLogger.logMeal] referencia um `food_id`
/// que não existe no catálogo ([FoodRepository]).
class FoodNotFoundException implements Exception {
  final String foodId;
  FoodNotFoundException(this.foodId);

  @override
  String toString() => 'alimento não encontrado no catálogo: $foodId';
}

/// Registra uma refeição no diário alimentar: recebe alimento(s) +
/// quantidade, calcula macros totais e grava um `HealthEvent` tipo `meal`
/// no Health Data Core (`docs/specs/nutricao.md`, seção "Modelo de
/// dados").
///
/// **`source` do `HealthEvent`:** usa `HealthEventSource.manual` — o
/// enum (`packages/health_core/lib/src/health_event.dart:41-57`) não tem
/// um valor específico para "veio de scanner de código de barras", e
/// nenhuma das origens já listadas ali (pedometer/wearable/manual/wger/
/// fasten/llm) é sobre isso. Decisão deste ciclo: **não inflar o enum**
/// — a proveniência de cada item (busca/scan/adição rápida) já é
/// registrada por item, dentro do `payload`
/// (`MealItemInputMethod.wireValue`), que é o lugar certo pra esse
/// detalhe: o campo `source` do `HealthEvent` descreve a origem do
/// **evento** (usuário interagindo com o app, sempre manual aqui — mesmo
/// quando um passo intermediário usou câmera), não de cada item dentro
/// dele.
class MealLogger {
  final FoodRepository foodRepository;
  final HealthDataCore core;

  MealLogger({required this.foodRepository, required this.core});

  /// Monta e grava o `HealthEvent` tipo `meal`. [occurredAt] é quando a
  /// refeição foi consumida (pode ser retroativo — `docs/specs/nutricao.md`);
  /// [recordedAt] default é "agora" (quando o registro está sendo feito).
  HealthEvent logMeal({
    required List<MealItemInput> items,
    required MealType mealType,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
    DateTime? recordedAt,
  }) {
    if (items.isEmpty) {
      throw ArgumentError('logMeal precisa de ao menos um item');
    }
    if (!occurredAt.isUtc) {
      throw ArgumentError('occurredAt precisa estar em UTC');
    }

    final itemPayloads = <Map<String, dynamic>>[];
    final totals = _MacroAccumulator();

    for (final item in items) {
      final food = foodRepository.findById(item.foodId);
      if (food == null) throw FoodNotFoundException(item.foodId);

      final factor = item.grams / 100.0;
      final itemMacros = _Macros(
        energyKcal: food.energyKcalPer100g * factor,
        carbohydrates: food.carbohydratesPer100g * factor,
        fat: food.fatPer100g * factor,
        protein: food.proteinPer100g * factor,
        saturatedFat: food.saturatedFatPer100g == null ? null : food.saturatedFatPer100g! * factor,
        sugar: food.sugarPer100g == null ? null : food.sugarPer100g! * factor,
        fiber: food.fiberPer100g == null ? null : food.fiberPer100g! * factor,
        sodium: food.sodiumPer100g == null ? null : food.sodiumPer100g! * factor,
      );
      totals.add(itemMacros);

      itemPayloads.add({
        'food_id': food.id,
        'name': food.name,
        'barcode': food.barcode,
        'source': food.source.wireValue,
        'input_method': item.inputMethod.wireValue,
        'grams': item.grams,
        'unit': 'g',
        ...itemMacros.toPayload(),
      });
    }

    final event = HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.meal,
      source: HealthEventSource.manual,
      occurredAt: occurredAt,
      occurredAtTzOffsetMinutes: occurredAtTzOffsetMinutes,
      recordedAt: recordedAt ?? DateTime.now().toUtc(),
      payload: {
        'meal_type': mealType.wireValue,
        'items': itemPayloads,
        'totals': totals.toPayload(),
      },
      confidence: 1.0,
    );

    core.insertEvent(event);
    return event;
  }
}

class _Macros {
  final double energyKcal;
  final double carbohydrates;
  final double fat;
  final double protein;
  final double? saturatedFat;
  final double? sugar;
  final double? fiber;
  final double? sodium;

  _Macros({
    required this.energyKcal,
    required this.carbohydrates,
    required this.fat,
    required this.protein,
    this.saturatedFat,
    this.sugar,
    this.fiber,
    this.sodium,
  });

  Map<String, dynamic> toPayload() => {
        'energy_kcal': energyKcal,
        'carbohydrates_g': carbohydrates,
        'fat_g': fat,
        'protein_g': protein,
        if (saturatedFat != null) 'saturated_fat_g': saturatedFat,
        if (sugar != null) 'sugar_g': sugar,
        if (fiber != null) 'fiber_g': fiber,
        if (sodium != null) 'sodium_g': sodium,
      };
}

class _MacroAccumulator {
  double energyKcal = 0;
  double carbohydrates = 0;
  double fat = 0;
  double protein = 0;
  double saturatedFat = 0;
  double sugar = 0;
  double fiber = 0;
  double sodium = 0;
  bool _hasSaturatedFat = false;
  bool _hasSugar = false;
  bool _hasFiber = false;
  bool _hasSodium = false;

  void add(_Macros m) {
    energyKcal += m.energyKcal;
    carbohydrates += m.carbohydrates;
    fat += m.fat;
    protein += m.protein;
    if (m.saturatedFat != null) {
      saturatedFat += m.saturatedFat!;
      _hasSaturatedFat = true;
    }
    if (m.sugar != null) {
      sugar += m.sugar!;
      _hasSugar = true;
    }
    if (m.fiber != null) {
      fiber += m.fiber!;
      _hasFiber = true;
    }
    if (m.sodium != null) {
      sodium += m.sodium!;
      _hasSodium = true;
    }
  }

  Map<String, dynamic> toPayload() => {
        'energy_kcal': energyKcal,
        'carbohydrates_g': carbohydrates,
        'fat_g': fat,
        'protein_g': protein,
        if (_hasSaturatedFat) 'saturated_fat_g': saturatedFat,
        if (_hasSugar) 'sugar_g': sugar,
        if (_hasFiber) 'fiber_g': fiber,
        if (_hasSodium) 'sodium_g': sodium,
      };
}
