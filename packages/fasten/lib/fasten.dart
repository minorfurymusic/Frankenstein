/// Fasten Health — prontuário pessoal (PHR/FHIR), papel opcional e
/// federado (`docs/adr/004-wger-fasten.md`, aceita). O Frankstein nunca
/// linka o código do Fasten (GPL-3.0, continua GPL-3.0 como programa
/// separado, `docs/LICENSE-AUDIT.md` Cenário B) — só fala com a API FHIR
/// (padrão HL7) dele, sob ação explícita do usuário.
///
/// `FastenDocumentSample` (leitura, `externalId` obrigatório, guarda o
/// recurso FHIR cru — filtragem pro cérebro/LLM é trabalho futuro,
/// `.claude/rules/brain.md`) + `FastenClient` (interface — implementação
/// real sobre FHIR não feita aqui, precisa de servidor Fasten real
/// alcançável) + `FastenSyncLogger` (grava `clinical_doc`,
/// `source: fasten`, deduplicando reimportação da mesma janela) +
/// `sync_fasten_records` (ferramenta do cérebro).
library;

export 'src/fasten_client.dart';
export 'src/fasten_document_sample.dart';
export 'src/fasten_sync_logger.dart';
export 'src/fasten_tools.dart';
