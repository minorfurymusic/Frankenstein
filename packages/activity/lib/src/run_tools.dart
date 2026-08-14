import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

final Map<String, dynamic> getRunSummarySchema = {
  'type': 'object',
  'properties': {
    'event_id': {'type': 'string'},
  },
  'required': ['event_id'],
};

/// `get_run_summary` — ferramenta de leitura (`docs/ARQUITETURA.md:66-67`
/// lista `start_run` como a ferramenta mínima de corrida; esta é
/// complementar, mesmo padrão de `get_workout_plan` em
/// `packages/activity/lib/src/workout_tools.dart`). Devolve só o resumo
/// já calculado (distância, pace, splits, elevação) — nunca os pontos de
/// rota brutos (lat/lon), que ficam só no Health Data Core; expor
/// coordenadas por uma ferramenta do cérebro sem o fluxo de
/// compartilhamento (`.claude/rules/activity.md:20-21`, ofuscação de
/// 300 m) violaria a regra de privacidade de rota.
///
/// **`start_run` (escrita, inicia a gravação) não está implementada
/// neste ciclo** — depende da captura de GPS real, que é WRAP nativo do
/// OpenTracks no Android (`docs/adr/009-gps.md`), sem SDK/device Android
/// neste ambiente. Registrar aqui um handler que não faz nada de real
/// seria fingir "feito" sem prova — `CLAUDE.md`, regra 1.
ToolSpec getRunSummarySpec() => ToolSpec(
      name: 'get_run_summary',
      description: 'Lê o resumo (distância, pace, splits, elevação) de uma corrida/caminhada já gravada',
      write: false,
      confirm: false,
      module: 'activity',
      parametersSchema: getRunSummarySchema,
    );

ToolHandler getRunSummaryHandler(HealthDataCore core) {
  return (params) async {
    final event = core.getById(params['event_id'] as String);
    if (event == null || event.type != HealthEventType.gpsTrack) {
      return ToolResult.failure('corrida não encontrada: ${params['event_id']}');
    }
    return ToolResult.ok({
      'event_id': event.id,
      'occurred_at': event.occurredAt.toIso8601String(),
      ...event.payload,
    });
  };
}
