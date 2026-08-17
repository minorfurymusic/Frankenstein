/// Uma série registrada no wger (endpoint `/api/v2/workoutlog/` da API
/// REST v2 pública) — antes de virar `HealthEvent`. `externalId`
/// **obrigatório**: todo dado do wger é, por definição, de fonte
/// externa (`docs/ARQUITETURA.md`: "external_id -- id do evento na
/// fonte externa (wearable, wger, fasten)"), é o que habilita dedup por
/// `(source, external_id)` (`.claude/rules/datacore.md`) quando a mesma
/// janela é sincronizada de novo — mesmo raciocínio de
/// `packages/wearable/lib/src/heart_rate_sample.dart`.
class WgerSetLogSample {
  final String externalId;
  final String exerciseName;
  final int reps;
  final double weightKg;
  final DateTime recordedAt;
  final int tzOffsetMinutes;

  WgerSetLogSample({
    required this.externalId,
    required this.exerciseName,
    required this.reps,
    required this.weightKg,
    required this.recordedAt,
    required this.tzOffsetMinutes,
  }) {
    if (!recordedAt.isUtc) {
      throw ArgumentError('recordedAt precisa estar em UTC');
    }
    if (reps <= 0) {
      throw ArgumentError('reps precisa ser positivo');
    }
    if (weightKg < 0) {
      throw ArgumentError('weightKg não pode ser negativo');
    }
  }
}
