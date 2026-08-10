/// Uma leitura bruta do sensor de passos do aparelho.
///
/// Espelha a semântica real do `TYPE_STEP_COUNTER` do Android:
/// [cumulativeSteps] é a contagem acumulada desde o último boot do
/// aparelho, nunca diminui — exceto quando o aparelho reinicia, e o
/// contador volta a zero. Quem consome isso ([StepsRepository]) precisa
/// lidar com esse reset, não o sensor.
class StepsSample {
  final String deviceId;
  final DateTime timestampUtc;
  final int cumulativeSteps;

  /// Fuso local do aparelho no momento da leitura, em minutos — mesma
  /// razão de `HealthEvent.occurredAtTzOffsetMinutes`
  /// (`.claude/rules/00-inviolaveis.md`: "Timestamps em UTC, com timezone
  /// gravado à parte"): `timestampUtc` não carrega essa informação.
  final int tzOffsetMinutes;

  StepsSample({
    required this.deviceId,
    required this.timestampUtc,
    required this.cumulativeSteps,
    required this.tzOffsetMinutes,
  }) {
    if (!timestampUtc.isUtc) {
      throw ArgumentError('timestampUtc precisa estar em UTC');
    }
    if (cumulativeSteps < 0) {
      throw ArgumentError('cumulativeSteps não pode ser negativo');
    }
  }
}
