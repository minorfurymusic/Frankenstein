import 'dart:typed_data';

import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

import '../data/day_read_model.dart';
import '../data/household_measures.dart';
import '../data/meal_plan.dart';
import '../data/nutrition_store.dart';
import '../format.dart';
import 'activity_chat_tools.dart';
import 'plan_swaps.dart';

/// Refeição estimada pela IA a partir do que a pessoa escreveu no Cérebro
/// ("comi 3 ovos"). Ferramenta do app, não do pacote de nutrição: o
/// `log_meal` do pacote só aceita alimento do catálogo (`food_id`) e o
/// pacote segue a sala limpa (`.claude/rules/port.md`) — não muda sem a
/// especificação mudar antes. Os alimentos estimados só nascem ao
/// confirmar, como na foto do prato, e não entram em "Meus itens".
final Map<String, dynamic> logEstimatedMealSchema = {
  'type': 'object',
  'properties': {
    'meal_type': {
      'enum': ['breakfast', 'lunch', 'dinner', 'snack'],
    },
    'at': {'type': 'string', 'format': 'date-time'},
    'items': {
      'type': 'array',
      'minItems': 1,
      'items': {
        'type': 'object',
        'properties': {
          // Item já salvo no aparelho (código de barras ou refeição
          // repetida): grava esse alimento, não uma estimativa nova.
          'food_id': {'type': 'string'},
          'name': {'type': 'string', 'minLength': 1},
          'grams': {'type': 'number', 'exclusiveMinimum': 0},
          // Bebida: a quantidade em `grams` é em ml.
          'unit': {
            'type': 'string',
            'enum': ['g', 'ml'],
          },
          'kcal': {'type': 'number', 'minimum': 0},
          'protein_g': {'type': 'number', 'minimum': 0},
          'carbs_g': {'type': 'number', 'minimum': 0},
          'fat_g': {'type': 'number', 'minimum': 0},
          'sugar_g': {'type': 'number', 'minimum': 0},
        },
        'required': ['name', 'grams', 'kcal'],
      },
    },
  },
  'required': ['meal_type', 'items'],
};

ToolSpec logEstimatedMealSpec() => ToolSpec(
      name: 'log_estimated_meal',
      description: 'Registra uma refeição com alimentos e valores estimados pela IA (sempre estimativa)',
      write: true,
      confirm: true,
      module: 'nutrition',
      parametersSchema: logEstimatedMealSchema,
    );

ToolHandler logEstimatedMealHandler(
  NutritionStore nutrition,
  MealLogger logger, {
  required int Function() tzOffsetMinutesProvider,
}) {
  return (params) async {
    try {
      final items = <MealItemInput>[];
      for (final raw in (params['items'] as List).cast<Map<String, dynamic>>()) {
        final grams = (raw['grams'] as num).toDouble();
        double n(String k) => (raw[k] as num?)?.toDouble() ?? 0;
        final saved = raw['food_id'] is String ? nutrition.foods.findById(raw['food_id'] as String) : null;
        final food = saved ?? nutrition.createEstimatedFood(
          name: raw['name'] as String,
          grams: grams,
          kcal: n('kcal'),
          protein: n('protein_g'),
          carbs: n('carbs_g'),
          fat: n('fat_g'),
          sugar: (raw['sugar_g'] as num?)?.toDouble(),
          idPrefix: 'chat',
          liquid: raw['unit'] == 'ml',
        );
        items.add(MealItemInput(foodId: food.id, grams: grams, unit: raw['unit'] == 'ml' ? 'ml' : 'g'));
      }
      final at = params['at'] as String?;
      final event = logger.logMeal(
        items: items,
        mealType: MealType.fromWireValue(params['meal_type'] as String),
        occurredAt: at == null ? DateTime.now().toUtc() : DateTime.parse(at).toUtc(),
        occurredAtTzOffsetMinutes: tzOffsetMinutesProvider(),
      );
      return ToolResult.ok({'event_id': event.id, 'totals': event.payload['totals']});
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    }
  };
}

/// Humor contado na conversa (ADR-23/27): vira cartão; só grava ao
/// confirmar, no diário de Saúde › Saúde mental.
final Map<String, dynamic> logMoodSchema = {
  'type': 'object',
  'properties': {
    'mood': {'type': 'integer', 'minimum': 1, 'maximum': 5},
    'feelings': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'notes': {'type': 'string'},
  },
  'required': ['mood'],
};

ToolSpec logMoodSpec() => ToolSpec(
      name: 'log_mood',
      description: 'Registra o humor do dia contado na conversa',
      write: true,
      confirm: true,
      module: 'health_records',
      parametersSchema: logMoodSchema,
    );

ToolHandler logMoodHandler(MoodLogger logger, {required int Function() tzOffsetMinutesProvider}) {
  return (params) async {
    try {
      final e = logger.log(
        mood: params['mood'] as int,
        feelings: [for (final f in (params['feelings'] as List? ?? const [])) '$f'],
        notes: params['notes'] as String?,
        occurredAt: DateTime.now().toUtc(),
        occurredAtTzOffsetMinutes: tzOffsetMinutesProvider(),
      );
      return ToolResult.ok({'event_id': e.id});
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    }
  };
}

/// Aviso fixo do app quando a IA marca `seek_care` — o texto é nosso, não
/// da IA (`.claude/rules/brain.md`: sintoma preocupante = orientar a
/// procurar profissional).
const seekCareMessage = 'Isso merece atenção de um profissional de saúde. Se for forte ou piorar, '
    'procure atendimento agora — em emergência, ligue 192 (SAMU). Se for sofrimento emocional ou '
    'pensamento de se machucar, ligue 188 (CVV, 24 h, gratuito) ou fale com alguém de confiança.';

/// Normaliza nome de remédio para comparar ("Dipirona Sódica" ~ "dipirona").
String _norm(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().trim().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Remédio cadastrado com o mesmo nome (ou cujo nome começa pelo que a
/// pessoa disse). A busca é **local**: a lista de remédios não vai à IA.
Medication? matchMedication(List<Medication> registered, String said) {
  final s = _norm(said);
  if (s.isEmpty) return null;
  for (final m in registered) {
    if (_norm(m.name) == s) return m;
  }
  final starts = [for (final m in registered) if (_norm(m.name).startsWith(s) || s.startsWith(_norm(m.name))) m];
  return starts.length == 1 ? starts.single : null;
}

/// Exercício da biblioteca com o mesmo nome (ou o único que começa pelo
/// que foi dito). Sem par, vira exercício livre com o nome dito.
CatalogExercise? matchExercise(String said) {
  final s = _norm(said);
  for (final e in exerciseCatalog) {
    if (_norm(e.name) == s) return e;
  }
  final starts = [for (final e in exerciseCatalog) if (_norm(e.name).startsWith(s) || s.startsWith(_norm(e.name))) e];
  return starts.length == 1 ? starts.single : null;
}

String _slug(String s) => _norm(s).replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

String _todayIso(DateTime now) =>
    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

/// Alimento já salvo no aparelho, na quantidade dita, no formato de um item
/// de `log_estimated_meal` (com `food_id`: grava esse alimento).
Map<String, dynamic> savedFoodItem(Food food, double grams, {String? unit}) {
  final f = grams / 100;
  final liquid = unit == null ? isLiquidFood(food) : unit == 'ml';
  return {
    'food_id': food.id,
    'name': food.name,
    'grams': grams,
    if (liquid) 'unit': 'ml',
    'kcal': food.energyKcalPer100g * f,
    'protein_g': food.proteinPer100g * f,
    'carbs_g': food.carbohydratesPer100g * f,
    'fat_g': food.fatPer100g * f,
    if (food.sugarPer100g != null) 'sugar_g': food.sugarPer100g! * f,
  };
}

/// Item dito na conversa ou visto na foto → item do cartão. Com código de
/// barras, o app procura o código nos itens cadastrados (a IA não sabe que
/// produto é): achou, usa os valores cadastrados; não achou, o item sai e
/// a pessoa fica sabendo em [messages].
Map<String, dynamic>? mealItemParams(PlateItem i, {Food? Function(String barcode)? findBarcode, required List<String> messages}) {
  final code = i.barcode;
  if (code != null) {
    final food = findBarcode?.call(code);
    if (food != null) return savedFoodItem(food, i.grams);
    messages.add('O código $code não está nos seus itens, então não registrei esse produto. '
        'Cadastre em Nutrição › Adicionar › Código de barras (dá para digitar os números) e mande de novo.');
    return null;
  }
  return {
    'name': i.name,
    'grams': i.grams,
    if (i.liquid) 'unit': 'ml',
    'kcal': i.kcal,
    'protein_g': i.proteinGrams,
    'carbs_g': i.carbsGrams,
    'fat_g': i.fatGrams,
    'sugar_g': ?i.sugarGrams,
  };
}

const _mealNames = {'breakfast': 'café da manhã', 'lunch': 'almoço', 'dinner': 'jantar', 'snack': 'lanche'};

/// "Repete o café da manhã de ontem": acha a refeição salva **no aparelho**
/// e devolve os itens dela para um cartão novo. `null` se não achou.
List<Map<String, dynamic>>? repeatedMealItems(
  Map<String, String> ask, {
  required DateTime now,
  required List<HealthEvent> Function(DateTime localDay) mealsOn,
  required Food? Function(String id) findFood,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final days = switch (ask['day']) {
    'today' => [today],
    'yesterday' => [today.subtract(const Duration(days: 1))],
    _ => [for (var i = 0; i < 30; i++) today.subtract(Duration(days: i))],
  };
  for (final d in days) {
    final found = [for (final e in mealsOn(d)) if (e.payload['meal_type'] == ask['meal_type']) e];
    if (found.isEmpty) continue;
    return [
      for (final raw in (found.last.payload['items'] as List? ?? const []).cast<Map<String, dynamic>>())
        if ((raw['grams'] as num?) != null && (raw['grams'] as num) > 0)
          if (findFood('${raw['food_id']}') case final food?)
            savedFoodItem(food, (raw['grams'] as num).toDouble(), unit: raw['unit'] as String?)
          else
            {
              'name': '${raw['name']}',
              'grams': (raw['grams'] as num).toDouble(),
              if (raw['unit'] == 'ml') 'unit': 'ml',
              'kcal': (raw['energy_kcal'] as num?)?.toDouble() ?? 0,
              'protein_g': (raw['protein_g'] as num?)?.toDouble() ?? 0,
              'carbs_g': (raw['carbohydrates_g'] as num?)?.toDouble() ?? 0,
              'fat_g': (raw['fat_g'] as num?)?.toDouble() ?? 0,
            },
    ];
  }
  return null;
}

/// Transforma o que a IA entendeu em chamadas de ferramenta — cada uma vira
/// um cartão no Cérebro. Perguntas sobre os próprios dados viram
/// ferramentas de leitura respondidas no aparelho.
///
/// [findBarcode], [findFood] e [mealsOn] procuram no aparelho o que está
/// salvo (itens cadastrados e refeições): nada disso vai à IA.
ToolCallPlan planFromReading(
  ChatReading r, {
  required List<Medication> medications,
  required DateTime now,
  Food? Function(String barcode)? findBarcode,
  Food? Function(String id)? findFood,
  List<HealthEvent> Function(DateTime localDay)? mealsOn,
}) {
  final calls = <ToolCallDecision>[];
  final messages = <String>[];
  if (r.transcript != null) messages.add('Transcrição: “${r.transcript}”');
  if (r.seekCare) messages.add(seekCareMessage);
  if (r.reply != null) messages.add(r.reply!);
  messages.addAll(r.incomplete);

  for (final w in r.water) {
    calls.add(ToolCallDecision('log_water', Map.of(w)));
  }
  for (final m in r.meals) {
    final items = [for (final i in m.items) ?mealItemParams(i, findBarcode: findBarcode, messages: messages)];
    if (items.isEmpty) continue;
    calls.add(ToolCallDecision('log_estimated_meal', {
      'meal_type': m.mealType,
      if (m.at != null) 'at': m.at,
      'items': items,
    }));
  }
  for (final ask in r.repeatMeals) {
    final items = mealsOn == null || findFood == null
        ? null
        : repeatedMealItems(ask, now: now, mealsOn: mealsOn, findFood: findFood);
    final name = _mealNames[ask['meal_type']] ?? 'refeição';
    if (items == null || items.isEmpty) {
      final when = switch (ask['day']) { 'today' => ' hoje', 'yesterday' => ' ontem', _ => ' nos últimos 30 dias' };
      messages.add('Não achei $name salvo$when.');
      continue;
    }
    calls.add(ToolCallDecision('log_estimated_meal', {'meal_type': ask['meal_type'], 'items': items}));
  }
  for (final d in r.doses) {
    final known = matchMedication(medications, d.name);
    final hasDose = d.doseAmount != null && d.doseUnit != null;
    if (known == null && !hasDose) {
      messages.add('Para registrar ${d.name}, me diga a dose (ex.: "${d.name} 500 mg às 9h") '
          'ou cadastre o remédio em Saúde › Remédios.');
      continue;
    }
    calls.add(ToolCallDecision('log_medication_dose', {
      if (known != null) 'medication_id': known.id,
      if (known == null) 'name': d.name,
      if (hasDose) 'dose_amount': d.doseAmount,
      if (hasDose) 'dose_unit': d.doseUnit,
      'status': d.status,
      if (d.at != null) 'at': d.at,
    }));
  }
  if (r.workouts.isNotEmpty) {
    // Uma sessão por mensagem: os exercícios ditos juntos são o mesmo treino.
    final sets = <Map<String, dynamic>>[];
    for (final w in r.workouts) {
      final known = matchExercise(w.exercise);
      for (var n = 1; n <= w.sets; n++) {
        sets.add({
          'exercise_id': known?.id ?? 'livre-${_slug(w.exercise)}',
          'exercise_name': known?.name ?? w.exercise,
          'set_number': n,
          'reps': w.reps,
          'load_kg': w.loadKg,
        });
      }
    }
    final at = r.workouts.map((w) => w.at).whereType<String>().firstOrNull;
    calls.add(ToolCallDecision('log_workout_session', {'sets': sets, 'at': ?at}));
  }
  for (final s in r.symptoms) {
    calls.add(ToolCallDecision('log_symptom', Map.of(s)));
  }
  for (final v in r.vitalSigns) {
    calls.add(ToolCallDecision('log_vital_sign', Map.of(v)));
  }
  for (final b in r.bodyMeasurements) {
    calls.add(ToolCallDecision('log_body_measurement', Map.of(b)));
  }
  final date = _todayIso(now);
  final yesterday = _todayIso(now.subtract(const Duration(days: 1)));
  for (final q in r.questions.toSet()) {
    final (tool, day) = switch (q) {
      'daily_summary' => ('get_daily_summary', date),
      'steps' => ('get_steps', date),
      'meals_today' => ('get_meals', date),
      'meals_yesterday' => ('get_meals', yesterday),
      _ => ('get_medication_agenda', date),
    };
    calls.add(ToolCallDecision(tool, {'date': day}));
  }
  for (final m in r.newMedications) {
    final known = matchMedication(medications, m.name);
    if (known != null) {
      messages.add('${known.name} já está em Saúde › Remédios.');
      continue;
    }
    calls.add(ToolCallDecision('add_medication', {
      'name': m.name,
      'dose_amount': m.doseAmount,
      'dose_unit': m.doseUnit,
      'times': m.times,
      'start_date': m.startDate ?? date,
    }));
  }
  if (r.mood != null) calls.add(ToolCallDecision('log_mood', Map.of(r.mood!)));
  for (final a in r.activities) {
    final walk = a['activity'] == 'walking' || a['activity'] == 'running';
    if (walk && a['distance_m'] != null && a['minutes'] == null) {
      // Só a distância: vira passos pela passada (o gasto entra pelos passos).
      calls.add(ToolCallDecision('log_manual_steps', {
        'distance_m': a['distance_m'],
        'round_trip': ?a['round_trip'],
        'label': ?a['label'],
        'at': ?a['at'],
      }));
    } else if (a['minutes'] != null) {
      calls.add(ToolCallDecision('log_other_activity', {
        'activity': a['activity'],
        'minutes': a['minutes'],
        'intensity': intensityForEffort(a['effort'] as int?).name,
        'label': ?a['label'],
        'at': ?a['at'],
      }));
    }
  }
  for (final h in r.history) {
    calls.add(ToolCallDecision('add_history_item', Map.of(h)));
  }
  if (calls.isEmpty && messages.isEmpty) {
    messages.add('Não encontrei nada para registrar nessa mensagem.');
  }
  return ToolCallPlan(
    calls: calls,
    messages: messages,
    // Resposta rápida nunca oferece dose (o RLT não sugere dose).
    suggestions: [for (final x in r.suggestions) if (!_looksLikeDose.hasMatch(x)) x],
  );
}

final _looksLikeDose = RegExp(r'\d\s*(mg|mcg|µg|g|ml|ui|gotas?|comprimidos?|c[aá]psulas?|unidades?)\b', caseSensitive: false);

/// Passo 2 do cérebro com o Gemini (ADR-11). Vai **só** o texto da
/// mensagem e a hora atual; remédios cadastrados são casados aqui no
/// aparelho.
class AiToolCaller implements PlanningToolCaller {
  final Future<GeminiClient> Function() client;
  final List<Medication> Function() medications;
  final DateTime Function() clock;

  /// O que já foi dito nesta conversa (para "pode salvar", "foi às 9h").
  final String Function()? history;

  /// Planos para as trocas equivalentes (ADR-26). O plano não vai à IA na
  /// leitura da mensagem; só o item a trocar vai, na segunda chamada.
  final MealPlan? Function()? mealPlan;
  final List<WorkoutPlan> Function()? workoutPlans;

  /// Itens e refeições salvos, procurados no aparelho (não vão à IA).
  final Food? Function(String barcode)? findBarcode;
  final Food? Function(String id)? findFood;
  final List<HealthEvent> Function(DateTime localDay)? mealsOn;

  AiToolCaller({
    required this.client,
    required this.medications,
    this.history,
    this.mealPlan,
    this.workoutPlans,
    this.findBarcode,
    this.findFood,
    this.mealsOn,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  @override
  Future<ToolCallPlan> plan(String userInput, List<ToolSpec> availableTools) => _plan(userInput, availableTools);

  /// Mensagem de voz: vai o áudio gravado (e a hora); volta a transcrição
  /// como primeira mensagem, para a pessoa conferir o que a IA ouviu.
  Future<ToolCallPlan> planVoice(Uint8List audio, String mimeType, List<ToolSpec> availableTools) =>
      _plan('', availableTools, audio: AiPart.file(audio, mimeType));

  Future<ToolCallPlan> _plan(String userInput, List<ToolSpec> availableTools, {AiPart? audio}) async {
    final now = clock();
    final reading = await readChatMessage(await client(), userInput, now: now, audio: audio, history: history?.call());
    var plan = planFromReading(
      reading,
      medications: medications(),
      now: now,
      findBarcode: findBarcode,
      findFood: findFood,
      mealsOn: mealsOn,
    );
    if (reading.planSwaps.isNotEmpty) {
      final swaps = await resolvePlanSwaps(
        reading.planSwaps,
        client: client,
        mealPlan: mealPlan ?? () => null,
        workoutPlans: workoutPlans ?? () => const [],
      );
      plan = ToolCallPlan(
        calls: [...plan.calls, ...swaps.calls],
        // "Não encontrei nada para registrar" não vale quando houve troca.
        messages: [
          for (final m in plan.messages)
            if (m != 'Não encontrei nada para registrar nessa mensagem.') m,
          ...swaps.messages,
        ],
        suggestions: [...plan.suggestions, ...swaps.suggestions],
      );
    }
    final names = {for (final t in availableTools) t.name};
    return ToolCallPlan(
      calls: [for (final c in plan.calls) if (names.contains(c.toolName)) c],
      messages: plan.messages,
      suggestions: plan.suggestions,
    );
  }
}

/// "O que eu comi hoje?" — respondido no aparelho, com o que está salvo.
final Map<String, dynamic> getMealsSchema = {
  'type': 'object',
  'properties': {
    'date': {'type': 'string', 'format': 'date', 'description': 'Dia local, AAAA-MM-DD'},
  },
  'required': ['date'],
};

ToolSpec getMealsSpec() => ToolSpec(
      name: 'get_meals',
      description: 'Refeições salvas num dia: hora, tipo, itens e kcal',
      write: false,
      confirm: false,
      module: 'nutrition',
      parametersSchema: getMealsSchema,
    );

ToolHandler getMealsHandler(DayReadModel days) {
  return (params) async {
    final d = DateTime.parse(params['date'] as String);
    final meals = days.eventsOnLocalDay(HealthEventType.meal, DateTime(d.year, d.month, d.day));
    return ToolResult.ok({
      'date': params['date'],
      'meals': [
        for (final e in meals)
          {
            'meal_type': e.payload['meal_type'],
            'time': hhmm(localOf(e.occurredAt, e.occurredAtTzOffsetMinutes)),
            'kcal': ((e.payload['totals'] as Map?)?['energy_kcal'] as num?)?.toDouble() ?? 0,
            'items': [
              for (final i in (e.payload['items'] as List? ?? const []).cast<Map<String, dynamic>>())
                {'name': i['name'], 'grams': i['grams'], 'unit': i['unit'] == 'ml' ? 'ml' : 'g'},
            ],
          },
      ],
    });
  };
}
