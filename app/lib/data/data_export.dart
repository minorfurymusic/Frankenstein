import 'dart:convert';

import 'package:frankstein_health_core/health_core.dart';

import '../app_dependencies.dart';

/// Exportação completa dos dados da pessoa (LGPD art. 18; nunca paga nem
/// limitada — `.claude/rules/00-inviolaveis.md`). JSON legível, em SI, com
/// fuso de cada registro. Gerado no aparelho; sai só pelo compartilhamento
/// do Android, por ação da pessoa.
Map<String, dynamic> buildFullExport(AppDependencies deps, {DateTime? now}) {
  final events = <Map<String, dynamic>>[];
  for (final type in HealthEventType.values) {
    for (final e in deps.core.queryByType(type)) {
      events.add({
        'id': e.id,
        'type': e.type.wireValue,
        'source': e.source.wireValue,
        'occurred_at_utc': e.occurredAt.toIso8601String(),
        'tz_offset_minutes': e.occurredAtTzOffsetMinutes,
        'recorded_at_utc': e.recordedAt.toIso8601String(),
        'confidence': e.confidence,
        if (e.deviceId != null) 'device_id': e.deviceId,
        if (e.externalId != null) 'external_id': e.externalId,
        if (e.correctsEventId != null) 'corrects_event_id': e.correctsEventId,
        'payload': e.payload,
        if (type == HealthEventType.gpsTrack)
          'route_points': [
            for (final p in deps.core.gpsTrackPoints(e.id))
              {
                'lat': p.latitude,
                'lon': p.longitude,
                if (p.elevationMeters != null) 'elevation_m': p.elevationMeters,
                'recorded_at_utc': p.recordedAt.toIso8601String(),
              },
          ],
      });
    }
  }
  final profile = deps.profileRepository.load();
  return {
    'format': 'rlt-export',
    'version': 1,
    'exported_at_utc': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'units': 'SI (kg, m, ml, kPa, mmol/L, °C); energia em kcal',
    if (profile != null)
      'profile': {
        'sex': profile.sex.wireValue,
        'birth_date': profile.birthDate.toIso8601String().substring(0, 10),
        'height_m': profile.heightMeters,
        'objective': profile.objective.wireValue,
        'rate_g_per_day': profile.rateGramsPerDay,
        'steps_goal': profile.stepsGoal,
        'strength_training': profile.strengthTraining,
        'high_protein': profile.highProtein,
      },
    'goal_overrides': deps.profileRepository.loadOverrides().toMap(),
    'medications': [
      for (final m in deps.medicationRepository.listAll())
        {
          'id': m.id,
          'name': m.name,
          'dose_amount': m.doseAmount,
          'dose_unit': m.doseUnit,
          'form': m.form.wireValue,
          'times_of_day_minutes': m.timesOfDay,
          'start_date': m.startDate.toIso(),
          'end_date': m.endDate?.toIso(),
          'notes': m.notes,
          'reminders_enabled': m.remindersEnabled,
        },
    ],
    'workout_plans': [
      for (final p in deps.workoutRepository.listPlans())
        {
          'id': p.id,
          'name': p.name,
          'exercises': [
            for (final e in p.exercises)
              {
                'exercise_id': e.exerciseId,
                'exercise_name': e.exerciseName,
                'target_sets': e.targetSets,
                'target_reps': e.targetReps,
                'target_load_kg': e.targetLoadKg,
              },
          ],
        },
    ],
    'my_foods': [
      for (final f in deps.nutrition.myItems())
        {
          'id': f.id,
          'name': f.name,
          'barcode': f.barcode,
          'energy_kcal_100g': f.energyKcalPer100g,
          'protein_g_100g': f.proteinPer100g,
          'carbohydrates_g_100g': f.carbohydratesPer100g,
          'fat_g_100g': f.fatPer100g,
        },
    ],
    'recipes': [for (final r in deps.nutrition.recipes()) r.toJson()],
    'diet_preferences': deps.nutrition.dietPreferences().toJson(),
    'events': events,
  };
}

String buildFullExportJson(AppDependencies deps) => const JsonEncoder.withIndent('  ').convert(buildFullExport(deps));
