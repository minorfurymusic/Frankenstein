import 'package:frankstein_tool_registry/tool_registry.dart';

import 'workout_repository.dart';
import 'workout_session.dart';
import 'workout_logger.dart';

final Map<String, dynamic> getWorkoutPlanSchema = {
  'type': 'object',
  'properties': {
    'plan_id': {'type': 'string'},
  },
  'required': ['plan_id'],
};

/// `get_workout_plan` — ferramenta de leitura. Devolve o plano de treino
/// (`docs/PRODUTO.md:28`) pelo id, mesmo padrão de
/// `packages/activity/lib/src/activity_tools.dart` (`getStepsSpec`).
ToolSpec getWorkoutPlanSpec() => ToolSpec(
      name: 'get_workout_plan',
      description: 'Lê um plano de treino pelo id',
      write: false,
      confirm: false,
      module: 'activity',
      parametersSchema: getWorkoutPlanSchema,
    );

ToolHandler getWorkoutPlanHandler(WorkoutRepository repository) {
  return (params) async {
    final plan = repository.findPlanById(params['plan_id'] as String);
    if (plan == null) {
      return ToolResult.failure('plano não encontrado: ${params['plan_id']}');
    }
    return ToolResult.ok({
      'id': plan.id,
      'name': plan.name,
      'exercises': plan.exercises
          .map((e) => {
                'exercise_id': e.exerciseId,
                'exercise_name': e.exerciseName,
                'target_sets': e.targetSets,
                'target_reps': e.targetReps,
                if (e.targetLoadKg != null) 'target_load_kg': e.targetLoadKg,
              })
          .toList(),
    });
  };
}

final Map<String, dynamic> logWorkoutSessionSchema = {
  'type': 'object',
  'properties': {
    'plan_id': {'type': 'string'},
    'notes': {'type': 'string'},
    'sets': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'exercise_id': {'type': 'string'},
          'exercise_name': {'type': 'string'},
          'set_number': {'type': 'integer'},
          'reps': {'type': 'integer'},
          'load_kg': {'type': 'number'},
          'rpe': {'type': 'number'},
        },
        'required': ['exercise_id', 'exercise_name', 'set_number', 'reps', 'load_kg'],
      },
    },
    'at': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['sets'],
};

/// `log_workout_session` — ferramenta de escrita. Registra uma sessão de
/// treino real via [WorkoutLogger], mesmo padrão de
/// `packages/nutrition/lib/src/nutrition_tools.dart` (`logMealSpec`/`logMealHandler`).
ToolSpec logWorkoutSessionSpec() => ToolSpec(
      name: 'log_workout_session',
      description: 'Registra uma sessão de treino concluída',
      write: true,
      confirm: true,
      module: 'activity',
      parametersSchema: logWorkoutSessionSchema,
    );

/// [tzOffsetMinutesProvider]: mesmo motivo de `logMealHandler`
/// (`packages/nutrition/lib/src/nutrition_tools.dart:47-54`) — o contrato
/// JSON não carrega fuso horário, só o instante `at`.
ToolHandler logWorkoutSessionHandler(
  WorkoutLogger logger, {
  required int Function() tzOffsetMinutesProvider,
}) {
  return (params) async {
    final setsRaw = params['sets'] as List;
    final sets = setsRaw.map((raw) {
      final map = raw as Map<String, dynamic>;
      return SetEntry(
        exerciseId: map['exercise_id'] as String,
        exerciseName: map['exercise_name'] as String,
        setNumber: map['set_number'] as int,
        reps: map['reps'] as int,
        loadKg: (map['load_kg'] as num).toDouble(),
        rpe: (map['rpe'] as num?)?.toDouble(),
      );
    }).toList();

    final input = WorkoutSessionInput(
      planId: params['plan_id'] as String?,
      sets: sets,
      notes: params['notes'] as String?,
    );

    final atRaw = params['at'] as String?;
    final occurredAt = atRaw != null ? DateTime.parse(atRaw).toUtc() : DateTime.now().toUtc();

    final event = logger.logSession(
      input,
      occurredAt: occurredAt,
      occurredAtTzOffsetMinutes: tzOffsetMinutesProvider(),
    );

    return ToolResult.ok({
      'event_id': event.id,
      'sets_count': event.payload['sets_count'],
    });
  };
}
