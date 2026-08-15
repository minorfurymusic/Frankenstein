/// Uma leitura de frequência cardíaca vinda do Health Connect — antes de
/// virar `HealthEvent` (`docs/PRODUTO.md:62`: "Pulseira BLE sincroniza FC
/// e sono para o Health Data Core"). `externalId` é o id do registro no
/// Health Connect, obrigatório aqui: toda leitura de wearable é, por
/// definição, dado de fonte externa — é o que permite deduplicação por
/// `(source, external_id)` (`.claude/rules/datacore.md`) quando a mesma
/// janela é sincronizada de novo.
class HeartRateSample {
  final String externalId;
  final int bpm;
  final DateTime recordedAt;
  final int tzOffsetMinutes;

  HeartRateSample({
    required this.externalId,
    required this.bpm,
    required this.recordedAt,
    required this.tzOffsetMinutes,
  }) {
    if (!recordedAt.isUtc) {
      throw ArgumentError('recordedAt precisa estar em UTC');
    }
    if (bpm <= 0) {
      throw ArgumentError('bpm precisa ser positivo');
    }
  }
}
