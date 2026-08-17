/// Um recurso FHIR (`DocumentReference`, `Observation`, etc.) lido do
/// Fasten Health — antes de virar `HealthEvent` tipo `clinical_doc`.
/// `externalId` **obrigatório** (id do recurso no servidor FHIR): todo
/// dado do Fasten é, por definição, de fonte externa, dedup por
/// `(source, external_id)` (`.claude/rules/datacore.md`).
///
/// `resourceType`/`rawResource` guardam o recurso FHIR como veio —
/// **nunca resumido ou reinterpretado aqui**: quem decide o que é seguro
/// mostrar/usar de um documento clínico é a camada do cérebro na hora de
/// montar contexto pro LLM (`.claude/rules/brain.md`: "Prontuário/exame
/// bruto NUNCA entra no prompt. Só agregados e derivados") — essa
/// filtragem ainda não existe (o cérebro só tem roteador determinístico,
/// sem LLM real), fica registrada aqui como trabalho futuro, não como
/// garantia já implementada.
class FastenDocumentSample {
  final String externalId;
  final String resourceType;
  final String title;
  final Map<String, dynamic> rawResource;
  final DateTime recordedAt;
  final int tzOffsetMinutes;

  FastenDocumentSample({
    required this.externalId,
    required this.resourceType,
    required this.title,
    required this.rawResource,
    required this.recordedAt,
    required this.tzOffsetMinutes,
  }) {
    if (!recordedAt.isUtc) {
      throw ArgumentError('recordedAt precisa estar em UTC');
    }
  }
}
