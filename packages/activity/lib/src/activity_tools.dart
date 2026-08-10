import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

final Map<String, dynamic> getStepsSchema = {
  'type': 'object',
  'properties': {
    'date': {
      'type': 'string',
      'format': 'date',
      'description': 'Data no formato YYYY-MM-DD',
    },
  },
  'required': ['date'],
};

/// `get_steps` — ferramenta de leitura, uma das mínimas do MVP
/// (`docs/ARQUITETURA.md:66-67`). Soma o `count` de todos os
/// `HealthEvent`s tipo `steps` cujo `occurredAt` cai no dia pedido.
///
/// **Simplificação registrada:** o dia é tratado em UTC (`[00:00,
/// 24:00)` do `date` recebido), não no fuso local de cada evento —
/// `occurredAtTzOffsetMinutes` existe no schema mas esta primeira versão
/// não o usa pra reconstruir o "dia local" de verdade. Para a maior
/// parte dos fusos isso já é correto na prática; fica como débito
/// conhecido, não erro escondido.
ToolSpec getStepsSpec() => ToolSpec(
      name: 'get_steps',
      description: 'Total de passos contados num dia',
      write: false,
      confirm: false,
      module: 'activity',
      parametersSchema: getStepsSchema,
    );

ToolHandler getStepsHandler(HealthDataCore core) {
  return (params) async {
    final date = DateTime.parse(params['date'] as String);
    final from = DateTime.utc(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    final events = core.queryByType(HealthEventType.steps, from: from, to: to);
    final total = events.fold<int>(0, (sum, e) => sum + (e.payload['count'] as int));

    return ToolResult.ok({
      'date': params['date'],
      'total_steps': total,
      'events_counted': events.length,
    });
  };
}
