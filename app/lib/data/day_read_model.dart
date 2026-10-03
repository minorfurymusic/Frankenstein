import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';

import '../format.dart';
import 'health_read_model.dart';

/// Totais de um dia **local** — o dia de quem usa, não o dia UTC. Cada
/// evento é filtrado pela hora local gravada com ele (UTC + fuso à parte),
/// então um lanche às 22:00 em Brasília (01:00 UTC do dia seguinte) conta
/// no dia certo.
class DayTotals {
  final DateTime day;
  final int steps;
  final double energyKcal;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double fiberGrams;
  final double waterMl;
  final int mealCount;
  final int workoutCount;
  final double runMeters;
  final List<HealthEvent> meals;

  const DayTotals({
    required this.day,
    required this.steps,
    required this.energyKcal,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.fiberGrams,
    required this.waterMl,
    required this.mealCount,
    required this.workoutCount,
    required this.runMeters,
    required this.meals,
  });
}

class DayReadModel {
  final HealthDataCore core;
  DayReadModel({required this.core});

  List<HealthEvent> eventsOnLocalDay(HealthEventType type, DateTime day) {
    final start = DateTime.utc(day.year, day.month, day.day);
    final events = core.queryByType(
      type,
      from: start.subtract(const Duration(days: 1)),
      to: start.add(const Duration(days: 2)),
    );
    return events.where((e) {
      final local = localOf(e.occurredAt, e.occurredAtTzOffsetMinutes);
      return local.year == day.year && local.month == day.month && local.day == day.day;
    }).toList();
  }

  DayTotals totals(DateTime day) {
    final meals = eventsOnLocalDay(HealthEventType.meal, day);
    double sum(String key) => meals.fold(0.0, (s, e) {
          final totals = e.payload['totals'] as Map<String, dynamic>? ?? const {};
          return s + ((totals[key] as num?)?.toDouble() ?? 0);
        });
    return DayTotals(
      day: DateTime(day.year, day.month, day.day),
      steps: eventsOnLocalDay(HealthEventType.steps, day).fold(0, (s, e) => s + (e.payload['count'] as num).toInt()),
      energyKcal: sum('energy_kcal'),
      proteinGrams: sum('protein_g'),
      carbsGrams: sum('carbohydrates_g'),
      fatGrams: sum('fat_g'),
      fiberGrams: sum('fiber_g'),
      waterMl: eventsOnLocalDay(HealthEventType.water, day).fold(0.0, (s, e) => s + (e.payload['amount_ml'] as num).toDouble()),
      mealCount: meals.length,
      workoutCount: eventsOnLocalDay(HealthEventType.workoutSession, day).length,
      runMeters: eventsOnLocalDay(HealthEventType.gpsTrack, day)
          .fold(0.0, (s, e) => s + ((e.payload['distance_meters'] as num?)?.toDouble() ?? 0)),
      meals: meals,
    );
  }
}

/// Por que não há meta calculada ainda.
enum GoalsMissing { profile, weight }

/// Junta perfil + medida mais recente + atividade do dia e devolve as metas
/// (ADR-15). `missing` diz o que falta preencher quando não dá para
/// calcular.
class GoalsService {
  final ProfileRepository profiles;
  final HealthReadModel health;
  final DayReadModel days;

  GoalsService({required this.profiles, required this.health, required this.days});

  GoalsMissing? missing() {
    if (profiles.load() == null) return GoalsMissing.profile;
    if (health.weights(days: 3650).isEmpty) return GoalsMissing.weight;
    return null;
  }

  DailyGoals? goalsFor(DateTime day) {
    final profile = profiles.load();
    final weights = health.weights(days: 3650);
    if (profile == null || weights.isEmpty) return null;
    final fat = health.measurements('body_fat', days: 3650);
    final totals = days.totals(day);
    return computeDailyGoals(
      profile,
      DayInputs(
        weightKg: weights.first.value,
        bodyFatFraction: fat.isEmpty ? null : fat.first.value / 100,
        steps: totals.steps,
        // TODO(frankstein): somar o gasto dos treinos/corridas por MET (Compêndio 2024) no ciclo da aba Exercícios.
        exerciseKcal: 0,
        date: day,
      ),
      overrides: profiles.loadOverrides(),
    );
  }
}
