import 'package:frankstein_tool_registry/tool_registry.dart';

import 'wger_sync_logger.dart';

final Map<String, dynamic> syncWgerSchema = {
  'type': 'object',
  'properties': {
    'from': {'type': 'string', 'format': 'date-time'},
    'to': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['from', 'to'],
};

/// `sync_wger` — ferramenta de escrita: grava no Health Data Core séries
/// importadas do wger, então exige confirmação
/// (`.claude/rules/brain.md`, passo 4) mesmo sendo "só sincronizar dado
/// que já existe em outro serviço" — mesmo raciocínio de `sync_wearable`
/// (`packages/wearable`).
ToolSpec syncWgerSpec() => ToolSpec(
      name: 'sync_wger',
      description: 'Sincroniza séries de treino do wger para o Health Data Core',
      write: true,
      confirm: true,
      module: 'wger',
      parametersSchema: syncWgerSchema,
    );

ToolHandler syncWgerHandler(WgerSyncLogger logger) {
  return (params) async {
    final from = DateTime.parse(params['from'] as String).toUtc();
    final to = DateTime.parse(params['to'] as String).toUtc();

    final result = await logger.sync(from: from, to: to);

    return ToolResult.ok({
      'synced': result.synced,
      'already_synced': result.alreadySynced,
    });
  };
}
