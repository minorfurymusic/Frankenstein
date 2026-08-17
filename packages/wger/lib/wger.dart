/// wger — catálogo/treino, papel opcional e federado
/// (`docs/adr/004-wger-fasten.md`, aceita). O Frankstein nunca linka o
/// código do wger (AGPL-3.0, continua AGPL-3.0 como programa separado,
/// `docs/LICENSE-AUDIT.md` Cenário B) — só fala com a API REST v2
/// pública dele, sob ação explícita do usuário.
///
/// `WgerSetLogSample` (leitura, `externalId` obrigatório) +
/// `WgerClient` (interface — implementação real sobre a API REST não
/// feita aqui, precisa de servidor wger real alcançável) +
/// `WgerSyncLogger` (grava `set_log`, `source: wger`, deduplicando
/// reimportação da mesma janela) + `sync_wger` (ferramenta do cérebro).
library;

export 'src/wger_client.dart';
export 'src/wger_set_log_sample.dart';
export 'src/wger_sync_logger.dart';
export 'src/wger_tools.dart';
