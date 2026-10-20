import 'dart:convert';

import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

/// Plano de treino pedido no Cérebro ("crie o treino para mim às 18:30"):
/// vira ficha em Exercícios › Academia, como a ficha fotografada (ADR-19),
/// e o horário dito liga o lembrete "Hora do treino" (decisão do usuário,
/// 2026-10-20). Nada vira treino feito.
final Map<String, dynamic> addWorkoutPlanSchema = {
  'type': 'object',
  'properties': {
    'name': {'type': 'string', 'minLength': 1},
    'exercises': {
      'type': 'array',
      'minItems': 1,
      'items': {
        'type': 'object',
        'properties': {
          'exercise_id': {'type': 'string', 'minLength': 1},
          'exercise_name': {'type': 'string', 'minLength': 1},
          'sets': {'type': 'integer', 'minimum': 1},
          'reps': {'type': 'integer', 'minimum': 1},
          'load_kg': {'type': 'number', 'exclusiveMinimum': 0},
        },
        'required': ['exercise_id', 'exercise_name', 'sets', 'reps'],
      },
    },
    // Minutos desde 00:00, hora local.
    'reminder_minutes': {'type': 'integer', 'minimum': 0, 'maximum': 1439},
  },
  'required': ['name', 'exercises'],
};

ToolSpec addWorkoutPlanSpec() => ToolSpec(
      name: 'add_workout_plan',
      description: 'Cria um plano de treino (ficha) e, se houver horário, liga o lembrete do treino',
      write: true,
      confirm: true,
      module: 'workout',
      parametersSchema: addWorkoutPlanSchema,
    );

ToolHandler addWorkoutPlanHandler(WorkoutRepository repository, ProfileRepository settings) {
  return (params) async {
    final id = HealthDataCore.newId();
    repository.savePlan(WorkoutPlan(
      id: id,
      name: params['name'] as String,
      exercises: [
        for (final e in (params['exercises'] as List).cast<Map<String, dynamic>>())
          PlannedExercise(
            exerciseId: e['exercise_id'] as String,
            exerciseName: e['exercise_name'] as String,
            targetSets: e['sets'] as int,
            targetReps: e['reps'] as int,
            targetLoadKg: (e['load_kg'] as num?)?.toDouble(),
          ),
      ],
    ));
    final minutes = params['reminder_minutes'] as int?;
    if (minutes != null) {
      // Mesmo formato de Conta › Lembretes; água fica como estava.
      final raw = settings.getSetting('reminders');
      final prefs = raw == null
          ? <String, dynamic>{'water_on': false, 'water_every_hours': 2}
          : jsonDecode(raw) as Map<String, dynamic>;
      prefs['workout_on'] = true;
      prefs['workout_time'] = minutes;
      settings.setSetting('reminders', jsonEncode(prefs));
    }
    return ToolResult.ok({'plan_id': id});
  };
}
