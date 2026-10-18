import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

import '../data/meal_plan.dart';

/// Trocas equivalentes no plano (ADR-26): alimento por outro de calorias e
/// proteína parecidas na mesma refeição; exercício por outro do mesmo
/// grupo muscular. Sempre como cartão confirmado; metas não mudam.

String _plain(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().trim().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

/// "ovo" acha "2 ovos fritos": compara pelo começo de cada palavra.
bool mentions(String text, String said) {
  final words = _plain(text).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
  final wanted = _plain(said).split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 3).toList();
  if (wanted.isEmpty) return false;
  return wanted.every((w) => words.any((x) => x.startsWith(w.length > 4 ? w.substring(0, w.length - 1) : w)));
}

String mealLabel(MealType t) => switch (t) {
      MealType.breakfast => 'Café da manhã',
      MealType.lunch => 'Almoço',
      MealType.dinner => 'Jantar',
      MealType.snack => 'Lanche',
    };

// ---------- IA: alimento equivalente ----------

const mealSwapSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'description': {'type': 'string'},
    'kcal': {'type': 'number'},
    'protein_g': {'type': 'number'},
    'carbs_g': {'type': 'number'},
    'fat_g': {'type': 'number'},
  },
  'required': ['description', 'kcal', 'protein_g', 'carbs_g', 'fat_g'],
};

const mealSwapInstruction = '''
Você ajuda uma pessoa a manter o plano alimentar feito pelo profissional dela, trocando um item que ela enjoou por outro equivalente na mesma refeição.
- Devolva UM item, com quantidade caseira ou em gramas na descrição (ex.: "Bife grelhado 100 g"), e kcal, protein_g, carbs_g e fat_g dessa porção (valores típicos de tabelas brasileiras, como a TACO).
- Mantenha calorias e proteína parecidas com o item original (diferença de no máximo 10%). Ajuste a quantidade para isso.
- Se a pessoa disse pelo que quer trocar, use isso, ajustando a quantidade. Se não, escolha algo comum no Brasil, que combine com a refeição e seja diferente do original.
- Não mude metas, não sugira suplemento, remédio nem dieta nova. Sem comentários.
''';

Future<MealPlanItem> suggestMealSwap(GeminiClient client, {required MealPlanItem item, required MealType mealType, String? replacement}) async {
  String n(double? v) => v == null ? '?' : v.toStringAsFixed(0);
  final json = await client.generateJson(
    system: mealSwapInstruction,
    parts: [
      AiPart.text('Refeição: ${mealLabel(mealType)}.\nItem do plano: ${item.description} — ${n(item.kcal)} kcal, '
          'proteína ${n(item.proteinGrams)} g, carboidrato ${n(item.carbsGrams)} g, gordura ${n(item.fatGrams)} g.\n'
          '${replacement == null ? 'A pessoa não aguenta mais esse item.' : 'A pessoa quer trocar por: $replacement.'}'),
    ],
    schema: mealSwapSchema,
  );
  double v(String k) => (json[k] as num).toDouble();
  return MealPlanItem(description: (json['description'] as String).trim(), kcal: v('kcal'), proteinGrams: v('protein_g'), carbsGrams: v('carbs_g'), fatGrams: v('fat_g'));
}

// ---------- Ferramentas (cartões) ----------

const _itemSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'description': {'type': 'string', 'minLength': 1},
    'kcal': {'type': 'number', 'minimum': 0},
    'protein_g': {'type': 'number', 'minimum': 0},
    'carbs_g': {'type': 'number', 'minimum': 0},
    'fat_g': {'type': 'number', 'minimum': 0},
  },
  'required': ['description'],
};

final swapPlanItemSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'meal_index': {'type': 'integer', 'minimum': 0},
    'item_index': {'type': 'integer', 'minimum': 0},
    'meal_type': {'type': 'string'},
    'from': _itemSchema,
    'to': _itemSchema,
  },
  'required': ['meal_index', 'item_index', 'from', 'to'],
};

ToolSpec swapPlanItemSpec() => ToolSpec(
      name: 'swap_plan_item',
      description: 'Troca um item do plano de refeições por outro equivalente (ADR-26)',
      write: true,
      confirm: true,
      module: 'nutrition',
      parametersSchema: swapPlanItemSchema,
    );

ToolHandler swapPlanItemHandler(MealPlanStore store) {
  return (params) async {
    final plan = store.load();
    final mi = params['meal_index'] as int;
    final ii = params['item_index'] as int;
    final from = (params['from'] as Map)['description'];
    if (plan == null || mi >= plan.meals.length || ii >= plan.meals[mi].items.length || plan.meals[mi].items[ii].description != from) {
      return ToolResult.failure('o plano mudou; peça a troca de novo');
    }
    final to = MealPlanItem.fromJson(Map<String, dynamic>.from(params['to'] as Map));
    final meal = plan.meals[mi];
    final meals = [...plan.meals];
    meals[mi] = MealPlanMeal(mealType: meal.mealType, time: meal.time, items: [...meal.items]..[ii] = to);
    store.save(MealPlan(
      name: plan.name,
      source: plan.source,
      createdAt: plan.createdAt,
      notes: plan.notes,
      estimated: true,
      attachments: plan.attachments,
      meals: meals,
    ));
    return ToolResult.ok({'meal_index': mi, 'item_index': ii});
  };
}

final swapPlanExerciseSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'plan_id': {'type': 'string'},
    'plan_name': {'type': 'string'},
    'exercise_index': {'type': 'integer', 'minimum': 0},
    'from_id': {'type': 'string'},
    'from_name': {'type': 'string'},
    'to_id': {'type': 'string'},
    'to_name': {'type': 'string'},
    'group': {'type': 'string'},
  },
  'required': ['plan_id', 'exercise_index', 'from_id', 'to_id', 'to_name'],
};

ToolSpec swapPlanExerciseSpec() => ToolSpec(
      name: 'swap_plan_exercise',
      description: 'Troca um exercício da ficha por outro do mesmo grupo muscular (ADR-26)',
      write: true,
      confirm: true,
      module: 'workout',
      parametersSchema: swapPlanExerciseSchema,
    );

ToolHandler swapPlanExerciseHandler(WorkoutRepository repository) {
  return (params) async {
    final plan = repository.findPlanById(params['plan_id'] as String);
    final i = params['exercise_index'] as int;
    if (plan == null || i >= plan.exercises.length || plan.exercises[i].exerciseId != params['from_id']) {
      return ToolResult.failure('a ficha mudou; peça a troca de novo');
    }
    final old = plan.exercises[i];
    final exercises = [...plan.exercises]
      ..[i] = PlannedExercise(
        exerciseId: params['to_id'] as String,
        exerciseName: params['to_name'] as String,
        targetSets: old.targetSets,
        targetReps: old.targetReps,
        // Outro exercício, outra carga: a pessoa acerta no primeiro treino.
        targetLoadKg: null,
      );
    repository.savePlan(WorkoutPlan(id: plan.id, name: plan.name, exercises: exercises));
    return ToolResult.ok({'plan_id': plan.id});
  };
}

// ---------- Do pedido ao cartão ----------

/// Transforma os pedidos de troca em cartões, mensagens e respostas rápidas.
Future<ToolCallPlan> resolvePlanSwaps(
  List<Map<String, dynamic>> swaps, {
  required Future<GeminiClient> Function() client,
  required MealPlan? Function() mealPlan,
  required List<WorkoutPlan> Function() workoutPlans,
}) async {
  final calls = <ToolCallDecision>[];
  final messages = <String>[];
  final suggestions = <String>[];
  for (final s in swaps) {
    final said = s['item'] as String;
    final replacement = s['replacement'] as String?;
    if (s['plan'] == 'meal') {
      final plan = mealPlan();
      if (plan == null) {
        messages.add('Você ainda não tem plano de refeições. Monte ou importe em Nutrição › Plano de refeições.');
        continue;
      }
      final wantedMeal = s['meal_type'] as String?;
      final found = <(int, int)>[];
      for (var mi = 0; mi < plan.meals.length; mi++) {
        if (wantedMeal != null && plan.meals[mi].mealType.wireValue != wantedMeal) continue;
        for (var ii = 0; ii < plan.meals[mi].items.length; ii++) {
          if (mentions(plan.meals[mi].items[ii].description, said)) found.add((mi, ii));
        }
      }
      if (found.isEmpty) {
        messages.add('Não achei "$said" no seu plano de refeições.');
        continue;
      }
      for (final (mi, ii) in found.take(3)) {
        final meal = plan.meals[mi];
        final item = meal.items[ii];
        final to = await suggestMealSwap(await client(), item: item, mealType: meal.mealType, replacement: replacement);
        if (item.kcal != null && item.kcal! > 0 && to.kcal != null && ((to.kcal! - item.kcal!).abs() / item.kcal!) > 0.25) {
          messages.add('A troca de "${item.description}" por "${to.description}" mudaria muito as calorias. '
              'Peça outra opção ou fale com seu nutricionista.');
          continue;
        }
        calls.add(ToolCallDecision('swap_plan_item', {
          'meal_index': mi,
          'item_index': ii,
          'meal_type': meal.mealType.wireValue,
          'from': item.toJson()..removeWhere((_, v) => v == null),
          'to': to.toJson()..removeWhere((_, v) => v == null),
        }));
      }
    } else {
      var matched = false;
      for (final plan in workoutPlans()) {
        for (var i = 0; i < plan.exercises.length; i++) {
          final ex = plan.exercises[i];
          if (!mentions(ex.exerciseName, said)) continue;
          matched = true;
          final current = exerciseCatalog.where((e) => e.id == ex.exerciseId).firstOrNull;
          if (current == null) {
            messages.add('${ex.exerciseName} não está na biblioteca de exercícios; troque em Exercícios › Academia.');
            continue;
          }
          final options = [for (final e in exerciseCatalog) if (e.group == current.group && e.id != current.id) e];
          final chosen = replacement == null
              ? null
              : exerciseCatalog.where((e) => mentions(e.name, replacement)).firstOrNull;
          if (chosen != null && chosen.group == current.group) {
            calls.add(ToolCallDecision('swap_plan_exercise', {
              'plan_id': plan.id,
              'plan_name': plan.name,
              'exercise_index': i,
              'from_id': ex.exerciseId,
              'from_name': ex.exerciseName,
              'to_id': chosen.id,
              'to_name': chosen.name,
              'group': current.group.label,
            }));
          } else {
            if (chosen != null) messages.add('${chosen.name} trabalha ${chosen.group.label.toLowerCase()}, não ${current.group.label.toLowerCase()}.');
            messages.add('Para ${ex.exerciseName} (${current.group.label.toLowerCase()}), dá para trocar por:');
            suggestions.addAll([for (final o in options.take(4)) 'Troca ${ex.exerciseName} por ${o.name}']);
          }
        }
      }
      if (!matched) messages.add('Não achei "$said" nas suas fichas de treino.');
    }
  }
  return ToolCallPlan(calls: calls, messages: messages, suggestions: suggestions);
}
