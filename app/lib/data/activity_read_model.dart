import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';

import '../format.dart';
import 'day_read_model.dart';
import 'health_read_model.dart';

enum ActivityKind { strength, gps, other }

/// Uma atividade do dia já com o gasto calculado (acima do repouso, ADR-15).
class ActivityEntry {
  final HealthEvent event;
  final ActivityKind kind;
  final String title;
  final DateTime local;
  final Duration? duration;
  final double? distanceMeters;
  final double kcal;
  final String? detail;

  const ActivityEntry({
    required this.event,
    required this.kind,
    required this.title,
    required this.local,
    required this.kcal,
    this.duration,
    this.distanceMeters,
    this.detail,
  });
}

/// Treinos, corridas/caminhadas gravadas e outras atividades do dia local,
/// com o gasto por MET: musculação pelo MET do Compêndio, outras pelo MET
/// da intensidade escolhida, corrida/caminhada com GPS pela velocidade média
/// (equações do ACSM). Usa o peso mais recente.
class ActivityReadModel {
  final DayReadModel days;
  final HealthReadModel health;
  ActivityReadModel({required this.days, required this.health});

  double? get _weightKg {
    final w = health.weights(days: 3650);
    return w.isEmpty ? null : w.first.value;
  }

  List<ActivityEntry> forDay(DateTime day) {
    final kg = _weightKg;
    double kcal(double met, Duration? d) =>
        kg == null || d == null ? 0 : HealthFormulas.activityKcal(met: met, weightKg: kg, duration: d);
    final out = <ActivityEntry>[];
    for (final e in days.eventsOnLocalDay(HealthEventType.workoutSession, day)) {
      final seconds = (e.payload['duration_seconds'] as num?)?.toInt();
      final duration = seconds == null ? null : Duration(seconds: seconds);
      final local = localOf(e.occurredAt, e.occurredAtTzOffsetMinutes);
      if (e.payload['kind'] == 'other_activity') {
        final activity = OtherActivity.fromCode(e.payload['activity'] as String);
        final met = (e.payload['met'] as num).toDouble();
        out.add(ActivityEntry(
          event: e,
          kind: ActivityKind.other,
          title: activity.label,
          local: local,
          duration: duration,
          kcal: kcal(met, duration),
          detail: _intensityLabel(e.payload['intensity'] as String?),
        ));
      } else {
        out.add(ActivityEntry(
          event: e,
          kind: ActivityKind.strength,
          title: 'Treino de academia',
          local: local,
          duration: duration,
          kcal: kcal(strengthTrainingMet, duration),
          detail: '${e.payload['sets_count']} séries',
        ));
      }
    }
    for (final e in days.eventsOnLocalDay(HealthEventType.gpsTrack, day)) {
      final meters = (e.payload['distance_meters'] as num?)?.toDouble() ?? 0;
      final seconds = (e.payload['duration_seconds'] as num?)?.toInt() ?? 0;
      final duration = Duration(seconds: seconds);
      final speed = seconds == 0 ? 0.0 : meters / (seconds / 60);
      out.add(ActivityEntry(
        event: e,
        kind: ActivityKind.gps,
        title: speed >= 100 ? 'Corrida' : 'Caminhada',
        local: localOf(e.occurredAt, e.occurredAtTzOffsetMinutes),
        duration: duration,
        distanceMeters: meters,
        kcal: seconds == 0 ? 0 : kcal(acsmMetForSpeed(speed), duration),
      ));
    }
    out.sort((a, b) => a.local.compareTo(b.local));
    return out;
  }

  double exerciseKcal(DateTime day) => forDay(day).fold(0.0, (s, a) => s + a.kcal);

  Duration activeTime(DateTime day) =>
      forDay(day).fold(Duration.zero, (s, a) => s + (a.duration ?? Duration.zero));

  static String? _intensityLabel(String? name) {
    for (final i in ActivityIntensity.values) {
      if (i.name == name) return i.label;
    }
    return null;
  }
}

String durationLabel(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return '$h h ${two(m)} min';
}

String paceLabel(double? secondsPerKm) {
  if (secondsPerKm == null || secondsPerKm <= 0 || secondsPerKm.isInfinite) return '—';
  final s = secondsPerKm.round();
  return '${s ~/ 60}:${two(s % 60)} /km';
}
