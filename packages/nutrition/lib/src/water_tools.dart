// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:frankstein_tool_registry/tool_registry.dart';

import 'water_logger.dart';

final Map<String, dynamic> logWaterSchema = {
  'type': 'object',
  'properties': {
    'amount_ml': {'type': 'number', 'exclusiveMinimum': 0},
    'at': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['amount_ml'],
};

/// `log_water` — ferramenta de escrita. Registra um consumo de água real
/// via [WaterLogger], mesmo padrão de `logMealSpec`/`logMealHandler`
/// neste mesmo pacote.
ToolSpec logWaterSpec() => ToolSpec(
      name: 'log_water',
      description: 'Registra consumo de água',
      write: true,
      confirm: true,
      module: 'nutrition',
      parametersSchema: logWaterSchema,
    );

/// [tzOffsetMinutesProvider]: mesmo motivo de `logMealHandler`
/// (`nutrition_tools.dart`) — o contrato JSON não carrega fuso horário.
ToolHandler logWaterHandler(
  WaterLogger logger, {
  required int Function() tzOffsetMinutesProvider,
}) {
  return (params) async {
    final atRaw = params['at'] as String?;
    final occurredAt = atRaw != null ? DateTime.parse(atRaw).toUtc() : DateTime.now().toUtc();

    final event = logger.log(
      amountMl: (params['amount_ml'] as num).toDouble(),
      occurredAt: occurredAt,
      occurredAtTzOffsetMinutes: tzOffsetMinutesProvider(),
    );

    return ToolResult.ok({
      'event_id': event.id,
      'amount_ml': event.payload['amount_ml'],
    });
  };
}
