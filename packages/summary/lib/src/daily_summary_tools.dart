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
    // Dia **local** de quem usa: cada evento conta no dia da hora local
    // gravada com ele (UTC + fuso à parte). Antes somava o dia UTC — no
    // Brasil, o que acontecia depois das 21:00 caía no dia seguinte.
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    List<HealthEvent> eventsOf(HealthEventType type) => core
        .queryByType(
          type,
          from: dayStart.subtract(const Duration(days: 1)),
          to: dayStart.add(const Duration(days: 2)),
        )
        .where((e) {
          final local = e.occurredAt.add(Duration(minutes: e.occurredAtTzOffsetMinutes));
          return local.year == date.year && local.month == date.month && local.day == date.day;
        })
        .toList();

    final stepsEvents = eventsOf(HealthEventType.steps);
    final totalSteps = stepsEvents.fold<int>(0, (sum, e) => sum + (e.payload['count'] as int));

    final mealEvents = eventsOf(HealthEventType.meal);
    final totalEnergyKcal = mealEvents.fold<double>(
      0,
      (sum, e) => sum + ((e.payload['totals'] as Map<String, dynamic>)['energy_kcal'] as num),
    );

    final waterEvents = eventsOf(HealthEventType.water);
    final totalWaterMl = waterEvents.fold<double>(
      0,
      (sum, e) => sum + (e.payload['amount_ml'] as num),
    );

    final workoutEvents = eventsOf(HealthEventType.workoutSession);
    final totalSets = workoutEvents.fold<int>(0, (sum, e) => sum + (e.payload['sets_count'] as int));

    final runEvents = eventsOf(HealthEventType.gpsTrack);
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
