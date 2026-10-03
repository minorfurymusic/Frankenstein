import 'package:frankstein_health_core/health_core.dart';

import 'activity_mets.dart';

/// Registro manual de "outras atividades" (natação, bike, futebol…): tipo,
/// duração e intensidade. Grava um `workout_session` sem séries, com o MET
/// usado — o gasto é calculado na leitura, pelo peso do dia.
class ActivityLogger {
  final HealthDataCore core;
  ActivityLogger({required this.core});

  HealthEvent log({
    required OtherActivity activity,
    required ActivityIntensity intensity,
    required Duration duration,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
    String? notes,
  }) {
    if (!occurredAt.isUtc) throw ArgumentError('occurredAt precisa estar em UTC');
    if (duration.inSeconds <= 0) throw ArgumentError('duração precisa ser maior que zero');
    final event = HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.workoutSession,
      source: HealthEventSource.manual,
      occurredAt: occurredAt,
      occurredAtTzOffsetMinutes: occurredAtTzOffsetMinutes,
      recordedAt: DateTime.now().toUtc(),
      payload: {
        'kind': 'other_activity',
        'activity': activity.code,
        'intensity': intensity.name,
        'met': activity.met(intensity),
        'duration_seconds': duration.inSeconds,
        'sets_count': 0,
        'exercise_ids': const <String>[],
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
      confidence: 1.0,
    );
    core.insertEvent(event);
    return event;
  }
}
