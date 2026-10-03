import 'package:frankstein_health_core/health_core.dart';

import 'run_calculator.dart';
import 'run_point.dart';

/// Lançada quando não há pontos suficientes (após o filtro de precisão)
/// pra formar uma rota — `RunLogger.logRun` recusa a gravar, em vez de
/// gravar um evento vazio/inútil.
class InsufficientRunDataException implements Exception {
  final String message;
  InsufficientRunDataException(this.message);

  @override
  String toString() => message;
}

/// Registra uma corrida/caminhada já concluída: filtra ruído
/// (`.claude/rules/activity.md:16`), calcula o resumo
/// ([RunCalculator.summarize]) e grava um `HealthEvent` tipo `gps_track`
/// com o resumo no `payload` + os pontos filtrados em `gps_track_points`
/// (`.claude/rules/datacore.md`: "gps_track.points em tabela própria").
///
/// **Fora do escopo desta classe:** a captura de GPS em si — gravador
/// próprio do app Android (`RunRecorderService.kt`, `docs/adr/009-gps.md`
/// revisão 1). `RunLogger` recebe os pontos já capturados (do gravador ou
/// de um GPX importado) e só cuida da parte determinística e testável:
/// filtrar, calcular, gravar.
/// Corrida ou caminhada (escolhida antes de iniciar).
enum RunKind {
  run('run'),
  walk('walk');

  final String wireValue;
  const RunKind(this.wireValue);

  static RunKind? fromWireValue(Object? v) => RunKind.values.where((k) => k.wireValue == v).firstOrNull;
}

/// Reconstrói os trechos (pausas) de uma rota gravada a partir de
/// `payload['segment_start_indices']`.
List<int> segmentsFromPayload(Map<String, dynamic> payload, int pointCount) {
  final starts = [for (final i in (payload['segment_start_indices'] as List?) ?? const [0]) (i as num).toInt()];
  final out = List<int>.filled(pointCount, 0);
  var seg = 0;
  for (var i = 0; i < pointCount; i++) {
    while (seg + 1 < starts.length && i >= starts[seg + 1]) {
      seg++;
    }
    out[i] = seg;
  }
  return out;
}

class RunLogger {
  final HealthDataCore core;

  RunLogger({required this.core});

  /// [rawPoints] são as leituras brutas, antes do filtro de precisão.
  /// Só os pontos que sobrevivem a [RunCalculator.filterByAccuracy] são
  /// gravados — `.claude/rules/activity.md:16` diz "descarte", não "marque
  /// como suspeito".
  HealthEvent logRun(
    List<RunPointInput> rawPoints, {
    required int occurredAtTzOffsetMinutes,
    double maxAccuracyMeters = RunCalculator.defaultMaxAccuracyMeters,
    DateTime? recordedAt,
    RunKind? kind,
  }) {
    final points = RunCalculator.filterSpeedOutliers(
      RunCalculator.filterByAccuracy(rawPoints, maxAccuracyMeters: maxAccuracyMeters),
    );
    if (points.length < 2) {
      throw InsufficientRunDataException(
          'menos de 2 pontos com precisão aceitável (${points.length}) — não dá pra formar uma rota');
    }

    final summary = RunCalculator.summarize(points);
    final occurredAt = points.first.recordedAt;

    final event = HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.gpsTrack,
      source: HealthEventSource.manual,
      occurredAt: occurredAt,
      occurredAtTzOffsetMinutes: occurredAtTzOffsetMinutes,
      recordedAt: recordedAt ?? DateTime.now().toUtc(),
      payload: {
        'distance_meters': summary.distanceMeters,
        'duration_seconds': summary.duration.inSeconds,
        'elevation_gain_meters': summary.elevationGainMeters,
        'average_pace_seconds_per_km': summary.averagePaceSecondsPerKm,
        'splits': summary.splits
            .map((s) => {
                  'km': s.km,
                  'duration_seconds': s.duration.inSeconds,
                  'pace_seconds_per_km': s.paceSecondsPerKm,
                })
            .toList(),
        'points_count': points.length,
        'points_discarded_by_accuracy': rawPoints.length - points.length,
        if (kind != null) 'activity': kind.wireValue,
        'segment_start_indices': [
          for (var i = 0; i < points.length; i++)
            if (i == 0 || points[i].segment != points[i - 1].segment) i,
        ],
      },
      confidence: 1.0,
    );
    core.insertEvent(event);

    core.insertGpsTrackPoints([
      for (var i = 0; i < points.length; i++)
        GpsTrackPoint(
          eventId: event.id,
          seq: i,
          latitude: points[i].latitude,
          longitude: points[i].longitude,
          elevationMeters: points[i].elevationMeters,
          accuracyMeters: points[i].accuracyMeters,
          recordedAt: points[i].recordedAt,
        ),
    ]);

    return event;
  }
}
