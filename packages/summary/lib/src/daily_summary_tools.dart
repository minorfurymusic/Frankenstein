import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

final Map<String, dynamic> getDailySummarySchema = {
  'type': 'object',
  'properties': {
    'date': {
      'type': 'string',
      'format': 'date',
      'description': 'Data no formato YYYY-MM-DD',
    },
  },
  'required': ['date'],
};

/// `get_daily_summary` — uma das ferramentas mínimas do MVP
/// (`docs/ARQUITETURA.md:66-67`). Junta passos, refeições, treino e
/// corrida/caminhada de um dia num resumo só, lendo do Health Data Core
/// compartilhado — não é "um módulo lendo o banco de outro"
/// (`.claude/rules/datacore.md`), é leitura da mesma fonte única que
/// `get_steps`/`log_meal`/`log_workout_session`/`RunLogger` já escrevem.
///
/// **Simplificação registrada, mesma de `get_steps`**
/// (`packages/activity/lib/src/activity_tools.dart:20-25`): o dia é
/// tratado em UTC `[00:00, 24:00)`, não no fuso local de cada evento.
ToolSpec getDailySummarySpec() => ToolSpec(
      name: 'get_daily_summary',
      description: 'Resumo do dia: passos, refeições, água, treino e corrida/caminhada',
      write: false,
      confirm: false,
      module: 'summary',
      parametersSchema: getDailySummarySchema,
    );

ToolHandler getDailySummaryHandler(HealthDataCore core) {
  return (params) async {
    final date = DateTime.parse(params['date'] as String);
    final from = DateTime.utc(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    final stepsEvents = core.queryByType(HealthEventType.steps, from: from, to: to);
    final totalSteps = stepsEvents.fold<int>(0, (sum, e) => sum + (e.payload['count'] as int));

    final mealEvents = core.queryByType(HealthEventType.meal, from: from, to: to);
    final totalEnergyKcal = mealEvents.fold<double>(
      0,
      (sum, e) => sum + ((e.payload['totals'] as Map<String, dynamic>)['energy_kcal'] as num),
    );

    final waterEvents = core.queryByType(HealthEventType.water, from: from, to: to);
    final totalWaterMl = waterEvents.fold<double>(
      0,
      (sum, e) => sum + (e.payload['amount_ml'] as num),
    );

    final workoutEvents = core.queryByType(HealthEventType.workoutSession, from: from, to: to);
    final totalSets = workoutEvents.fold<int>(0, (sum, e) => sum + (e.payload['sets_count'] as int));

    final runEvents = core.queryByType(HealthEventType.gpsTrack, from: from, to: to);
    final totalRunDistanceMeters = runEvents.fold<double>(
      0,
      (sum, e) => sum + (e.payload['distance_meters'] as num),
    );

    return ToolResult.ok({
      'date': params['date'],
      'steps': {
        'total': totalSteps,
        'events_counted': stepsEvents.length,
      },
      'meals': {
        'count': mealEvents.length,
        'total_energy_kcal': totalEnergyKcal,
      },
      'water': {
        'count': waterEvents.length,
        'total_amount_ml': totalWaterMl,
      },
      'workouts': {
        'count': workoutEvents.length,
        'total_sets': totalSets,
      },
      'runs': {
        'count': runEvents.length,
        'total_distance_meters': totalRunDistanceMeters,
      },
    });
  };
}
