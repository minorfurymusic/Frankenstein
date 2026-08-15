import 'package:frankstein_tool_registry/tool_registry.dart';

import 'wearable_sync_logger.dart';

final Map<String, dynamic> syncWearableSchema = {
  'type': 'object',
  'properties': {
    'from': {'type': 'string', 'format': 'date-time'},
    'to': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['from', 'to'],
};

/// `sync_wearable` — uma das ferramentas mínimas do MVP
/// (`docs/ARQUITETURA.md:81-82`). Escreve no Health Data Core (frequência
/// cardíaca e sono importados), então é ferramenta de escrita — `write`
/// implica `confirm` (`ToolSpec`, `.claude/rules/brain.md` passo 4), sem
/// exceção pra "é só sincronizar dado que já existe em outro app": ainda
/// é o cérebro decidindo gravar no Health Data Core.
ToolSpec syncWearableSpec() => ToolSpec(
      name: 'sync_wearable',
      description: 'Sincroniza frequência cardíaca e sono do wearable (via Health Connect) para o Health Data Core',
      write: true,
      confirm: true,
      module: 'wearable',
      parametersSchema: syncWearableSchema,
    );

ToolHandler syncWearableHandler(WearableSyncLogger logger) {
  return (params) async {
    final from = DateTime.parse(params['from'] as String).toUtc();
    final to = DateTime.parse(params['to'] as String).toUtc();

    final result = await logger.sync(from: from, to: to);

    return ToolResult.ok({
      'heart_rate_synced': result.heartRateSynced,
      'heart_rate_already_synced': result.heartRateAlreadySynced,
      'sleep_synced': result.sleepSynced,
      'sleep_already_synced': result.sleepAlreadySynced,
    });
  };
}
