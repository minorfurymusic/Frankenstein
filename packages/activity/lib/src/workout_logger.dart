import 'package:frankstein_health_core/health_core.dart';

import 'workout_session.dart';

/// Recorde pessoal de um exercício — maior `loadKg` já registrado em um
/// `set_log`, com o `reps` e a data daquela série (`docs/PRODUTO.md:28`:
/// "recordes, progressão"). Calculado por consulta sobre o histórico de
/// `set_log`, não armazenado como dado próprio — a mesma lógica de
/// "derivado, não guardado" que `docs/ARQUITETURA.md` já usa noutros
/// lugares do Health Data Core.
class PersonalRecord {
  final String exerciseId;
  final double loadKg;
  final int reps;
  final DateTime occurredAt;

  PersonalRecord({
    required this.exerciseId,
    required this.loadKg,
    required this.reps,
    required this.occurredAt,
  });
}

/// Registra uma sessão de treino já concluída: grava um `HealthEvent`
/// tipo `workout_session` (resumo) e um `HealthEvent` tipo `set_log` por
/// série (`.claude/rules/datacore.md`), cada `set_log` referenciando a
/// sessão via `session_event_id` no `payload` — granular por propósito,
/// mesma decisão documentada em `packages/activity/lib/src/workout_session.dart:1-4`.
class WorkoutLogger {
  final HealthDataCore core;

  WorkoutLogger({required this.core});

  /// Grava a sessão: 1 evento `workout_session` seguido de
  /// `input.sets.length` eventos `set_log`. Todos compartilham o mesmo
  /// `occurredAt`/`occurredAtTzOffsetMinutes` — a sessão é tratada como
  /// um só instante no tempo, não com timestamp por série (o app não
  /// captura isso ainda).
  HealthEvent logSession(
    WorkoutSessionInput input, {
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
    DateTime? recordedAt,
  }) {
    if (!occurredAt.isUtc) {
      throw ArgumentError('occurredAt precisa estar em UTC');
    }
    final effectiveRecordedAt = recordedAt ?? DateTime.now().toUtc();

    final sessionEvent = HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.workoutSession,
      source: HealthEventSource.manual,
      occurredAt: occurredAt,
      occurredAtTzOffsetMinutes: occurredAtTzOffsetMinutes,
      recordedAt: effectiveRecordedAt,
      payload: {
        if (input.planId != null) 'plan_id': input.planId,
        if (input.notes != null) 'notes': input.notes,
        'sets_count': input.sets.length,
        'exercise_ids': input.sets.map((s) => s.exerciseId).toSet().toList(),
      },
      confidence: 1.0,
    );
    core.insertEvent(sessionEvent);

    for (final set in input.sets) {
      final setEvent = HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.setLog,
        source: HealthEventSource.manual,
        occurredAt: occurredAt,
        occurredAtTzOffsetMinutes: occurredAtTzOffsetMinutes,
        recordedAt: effectiveRecordedAt,
        payload: {
          'session_event_id': sessionEvent.id,
          'exercise_id': set.exerciseId,
          'exercise_name': set.exerciseName,
          'set_number': set.setNumber,
          'reps': set.reps,
          'load_kg': set.loadKg,
          if (set.rpe != null) 'rpe': set.rpe,
        },
        confidence: 1.0,
      );
      core.insertEvent(setEvent);
    }

    return sessionEvent;
  }

  /// Recorde pessoal do exercício [exerciseId]: a série com maior
  /// `load_kg` entre todos os `set_log` já gravados. `null` se o
  /// exercício nunca foi registrado.
  PersonalRecord? personalRecord(String exerciseId) {
    final sets = core.queryByType(HealthEventType.setLog);
    PersonalRecord? best;
    for (final event in sets) {
      if (event.payload['exercise_id'] != exerciseId) continue;
      final loadKg = (event.payload['load_kg'] as num).toDouble();
      if (best == null || loadKg > best.loadKg) {
        best = PersonalRecord(
          exerciseId: exerciseId,
          loadKg: loadKg,
          reps: event.payload['reps'] as int,
          occurredAt: event.occurredAt,
        );
      }
    }
    return best;
  }
}
