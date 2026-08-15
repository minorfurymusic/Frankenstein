import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';

import 'share_card_data.dart';

/// Lançada quando alguém tenta montar um card a partir de um
/// `HealthEvent` do tipo errado — `.claude/rules/share.md`: "Nada
/// clínico tem card: exame, receita, prontuário, diagnóstico. Sem
/// exceção." A checagem de tipo aqui é o que torna essa regra
/// estrutural, não uma convenção que alguém pode esquecer de seguir:
/// `buildWorkoutShareCard`/`buildRunShareCard` simplesmente não aceitam
/// nenhum outro tipo de evento, `clinical_doc` incluído.
class WrongEventTypeForShareCardException implements Exception {
  final String message;
  WrongEventTypeForShareCardException(this.message);

  @override
  String toString() => message;
}

/// Monta o card de um treino a partir do `HealthEvent` tipo
/// `workout_session` gravado por `WorkoutLogger` (`packages/activity`).
/// [personalRecordSummary] é opcional e só entra se o chamador passar —
/// esta função não consulta `WorkoutLogger.personalRecord` sozinha,
/// porque isso exigiria saber qual exercício destacar; a tela decide.
WorkoutShareCardData buildWorkoutShareCard(
  HealthEvent workoutSessionEvent, {
  String? personalRecordSummary,
}) {
  if (workoutSessionEvent.type != HealthEventType.workoutSession) {
    throw WrongEventTypeForShareCardException(
        'buildWorkoutShareCard espera workout_session, recebeu ${workoutSessionEvent.type.wireValue}');
  }

  final exerciseIds = (workoutSessionEvent.payload['exercise_ids'] as List).cast<String>();

  return WorkoutShareCardData(
    title: 'Treino',
    setsCount: workoutSessionEvent.payload['sets_count'] as int,
    exerciseNames: exerciseIds,
    personalRecordSummary: personalRecordSummary,
  );
}

/// Monta o card de uma corrida/caminhada a partir do `HealthEvent` tipo
/// `gps_track` gravado por `RunLogger` (`packages/activity`) e dos
/// pontos de rota associados (`HealthDataCore.gpsTrackPoints`).
/// A rota é ofuscada aqui dentro (`obfuscateRouteEnds`,
/// `.claude/rules/share.md`) — quem chama esta função nunca vê a rota
/// crua sair do card.
RunShareCardData buildRunShareCard(
  HealthEvent gpsTrackEvent,
  List<GpsTrackPoint> points,
) {
  if (gpsTrackEvent.type != HealthEventType.gpsTrack) {
    throw WrongEventTypeForShareCardException(
        'buildRunShareCard espera gps_track, recebeu ${gpsTrackEvent.type.wireValue}');
  }

  final runPoints = points
      .map((p) => RunPointInput(
            latitude: p.latitude,
            longitude: p.longitude,
            recordedAt: p.recordedAt,
            elevationMeters: p.elevationMeters,
            accuracyMeters: p.accuracyMeters,
          ))
      .toList();
  final obfuscated = obfuscateRouteEnds(runPoints);

  return RunShareCardData(
    distanceMeters: (gpsTrackEvent.payload['distance_meters'] as num).toDouble(),
    duration: Duration(seconds: gpsTrackEvent.payload['duration_seconds'] as int),
    averagePaceSecondsPerKm: (gpsTrackEvent.payload['average_pace_seconds_per_km'] as num?)?.toDouble(),
    route: obfuscated.map((p) => RunShareRoutePoint(latitude: p.latitude, longitude: p.longitude)).toList(),
  );
}
