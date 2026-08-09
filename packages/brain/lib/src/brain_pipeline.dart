import 'package:frankstein_tool_registry/tool_registry.dart';

import 'confirmation.dart';
import 'pipeline_result.dart';
import 'tool_caller.dart';

/// O pipeline do cérebro — `.claude/rules/brain.md`, as 4 etapas
/// obrigatórias, nesta ordem:
/// 1. [callers] tentados em ordem (roteador determinístico primeiro;
///    LLM real ainda não existe nesta fase — ver [ToolCaller]).
/// 2. Parâmetros validados contra o JSON Schema da ferramenta decidida.
/// 3. Se a ferramenta exige confirmação (`ToolSpec.confirm`), pede via
///    [confirmationGate] antes de executar.
/// 4. Executa via [registry] — só depois de validado e (se preciso)
///    confirmado.
///
/// Não decide nada sobre política — só orquestra. Cada passo é testável
/// isoladamente (`ToolCaller`, validação, `ConfirmationGate`, `ToolRegistry`).
class BrainPipeline {
  final ToolRegistry registry;
  final List<ToolCaller> callers;
  final ConfirmationGate confirmationGate;

  BrainPipeline({
    required this.registry,
    required this.callers,
    required this.confirmationGate,
  });

  Future<PipelineResult> handle(String userInput) async {
    ToolCallDecision? decision;
    for (final caller in callers) {
      decision = caller.decide(userInput, registry.specs);
      if (decision != null) break;
    }
    if (decision == null) return PipelineResult.unresolved();

    if (!registry.has(decision.toolName)) {
      // Um ToolCaller decidiu uma ferramenta que não está neste
      // registro — trata como não resolvido em vez de deixar vazar
      // ToolNotFoundException pro chamador do pipeline.
      return PipelineResult.unresolved();
    }
    final spec = registry.specFor(decision.toolName);

    final validation = validateToolParameters(spec.parametersSchema, decision.params);
    if (!validation.valid) {
      return PipelineResult.rejected(decision.toolName, validation.errors);
    }

    if (spec.confirm) {
      final confirmed = await confirmationGate.confirm(spec, decision.params);
      if (!confirmed) {
        return PipelineResult.abortedByUser(decision.toolName);
      }
    }

    final result = await registry.execute(decision.toolName, decision.params);
    return PipelineResult.executed(decision.toolName, result);
  }
}
