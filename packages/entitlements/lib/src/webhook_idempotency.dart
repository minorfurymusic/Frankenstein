/// Webhooks idempotentes, chave `external_id + event_id`
/// (`.claude/rules/monetizacao.md`: "Webhooks idempotentes; fila de
/// retry; reconciliação diária"). Guarda em memória — produção precisa
/// de storage persistente (fila real, banco do servidor); fora de escopo
/// deste esqueleto, que não configura nenhum provedor ainda.
class WebhookIdempotencyGuard {
  final Set<String> _seen = {};

  /// Devolve `true` se este evento já foi processado antes (o chamador
  /// deve ignorá-lo); marca como processado na primeira chamada com essa
  /// chave.
  bool alreadyProcessed(String externalId, String eventId) {
    final key = '$externalId:$eventId';
    if (_seen.contains(key)) return true;
    _seen.add(key);
    return false;
  }
}
