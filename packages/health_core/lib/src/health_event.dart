/// Tipo de um [HealthEvent] — `docs/ARQUITETURA.md`, `.claude/rules/datacore.md`.
enum HealthEventType {
  steps,
  heartRate,
  sleep,
  meal,
  weight,
  workoutSession,
  setLog,
  gpsTrack,
  clinicalDoc;

  /// Valor gravado no banco — snake_case, igual à documentação.
  String get wireValue => switch (this) {
        HealthEventType.steps => 'steps',
        HealthEventType.heartRate => 'heart_rate',
        HealthEventType.sleep => 'sleep',
        HealthEventType.meal => 'meal',
        HealthEventType.weight => 'weight',
        HealthEventType.workoutSession => 'workout_session',
        HealthEventType.setLog => 'set_log',
        HealthEventType.gpsTrack => 'gps_track',
        HealthEventType.clinicalDoc => 'clinical_doc',
      };

  static HealthEventType fromWireValue(String value) => switch (value) {
        'steps' => HealthEventType.steps,
        'heart_rate' => HealthEventType.heartRate,
        'sleep' => HealthEventType.sleep,
        'meal' => HealthEventType.meal,
        'weight' => HealthEventType.weight,
        'workout_session' => HealthEventType.workoutSession,
        'set_log' => HealthEventType.setLog,
        'gps_track' => HealthEventType.gpsTrack,
        'clinical_doc' => HealthEventType.clinicalDoc,
        _ => throw ArgumentError('tipo de HealthEvent desconhecido: $value'),
      };
}

/// Origem de um [HealthEvent] — `docs/ARQUITETURA.md`, `.claude/rules/datacore.md`.
enum HealthEventSource {
  pedometer,
  wearable,
  manual,
  wger,
  fasten,
  llm;

  String get wireValue => name;

  static HealthEventSource fromWireValue(String value) =>
      HealthEventSource.values.firstWhere(
        (s) => s.name == value,
        orElse: () =>
            throw ArgumentError('fonte de HealthEvent desconhecida: $value'),
      );
}

/// Um evento de saúde — a unidade atômica do Health Data Core.
///
/// Append-only por design (`.claude/rules/datacore.md`): esta classe é
/// imutável, e o Core nunca faz UPDATE num evento já gravado. Correção é
/// sempre um [HealthEvent] novo com [correctsEventId] apontando para o
/// anterior.
///
/// `occurredAt`/`recordedAt` são sempre UTC — `occurredAtTzOffsetMinutes`
/// guarda o fuso em que o evento aconteceu de fato, separado do timestamp
/// (`.claude/rules/00-inviolaveis.md`: "Timestamps em UTC, com timezone
/// gravado à parte"). É um offset em minutos, não um nome de fuso IANA —
/// simplificação deliberada da Fase 3: reconstrói a hora local do
/// momento, mas não histórico de mudança de regra de DST da região.
class HealthEvent {
  final String id;
  final HealthEventType type;
  final HealthEventSource source;
  final DateTime occurredAt;
  final int occurredAtTzOffsetMinutes;
  final DateTime recordedAt;
  final Map<String, dynamic> payload;
  final double confidence;
  final String? deviceId;
  final String? externalId;
  final String? correctsEventId;

  HealthEvent({
    required this.id,
    required this.type,
    required this.source,
    required this.occurredAt,
    required this.occurredAtTzOffsetMinutes,
    required this.recordedAt,
    required this.payload,
    required this.confidence,
    this.deviceId,
    this.externalId,
    this.correctsEventId,
  }) {
    if (!occurredAt.isUtc) {
      throw ArgumentError(
          'occurredAt precisa estar em UTC (.claude/rules/00-inviolaveis.md)');
    }
    if (!recordedAt.isUtc) {
      throw ArgumentError('recordedAt precisa estar em UTC');
    }
    if (confidence < 0 || confidence > 1) {
      throw ArgumentError('confidence precisa estar entre 0.0 e 1.0');
    }
  }
}

/// Um ponto de uma rota de GPS — tabela própria (`gps_track_points`),
/// ligada ao [HealthEvent] do tipo `gpsTrack` por `event_id`
/// (`.claude/rules/datacore.md`: "gps_track.points em tabela própria").
class GpsTrackPoint {
  final String eventId;
  final int seq;
  final double latitude;
  final double longitude;
  final double? elevationMeters;
  final DateTime recordedAt;

  GpsTrackPoint({
    required this.eventId,
    required this.seq,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.elevationMeters,
  }) {
    if (!recordedAt.isUtc) {
      throw ArgumentError('recordedAt precisa estar em UTC');
    }
  }
}
