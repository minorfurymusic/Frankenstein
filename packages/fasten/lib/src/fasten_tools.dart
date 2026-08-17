import 'package:frankstein_tool_registry/tool_registry.dart';

import 'fasten_sync_logger.dart';

final Map<String, dynamic> syncFastenRecordsSchema = {
  'type': 'object',
  'properties': {
    'from': {'type': 'string', 'format': 'date-time'},
    'to': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['from', 'to'],
};

/// `sync_fasten_records` — ferramenta de escrita: grava no Health Data
/// Core documentos clínicos importados do Fasten, então exige
/// confirmação (`.claude/rules/brain.md`, passo 4) — dado de saúde
/// sensível entrando no aparelho ainda passa pela mesma barreira de
/// confirmação humana que qualquer outra escrita.
ToolSpec syncFastenRecordsSpec() => ToolSpec(
      name: 'sync_fasten_records',
      description: 'Sincroniza documentos clínicos do Fasten Health para o Health Data Core',
      write: true,
      confirm: true,
      module: 'fasten',
      parametersSchema: syncFastenRecordsSchema,
    );

ToolHandler syncFastenRecordsHandler(FastenSyncLogger logger) {
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
