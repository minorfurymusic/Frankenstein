import 'package:frankstein_tool_registry/tool_registry.dart';

import 'confirmation.dart';
import 'pipeline_result.dart';
import 'tool_caller.dart';

/// O pipeline do cérebro — `.claude/rules/brain.md`, as 4 etapas
/// obrigatórias, nesta ordem:
/// 1. [callers] tentados em ordem (roteador determinístico primeiro); o
///    que sobrar pode ir à IA por [handleWith] (ADR-11).
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
    return _run(decision);
  }

  /// Passo 2 (IA): [caller] devolve várias chamadas; cada uma passa pela
  /// mesma validação e pela mesma confirmação, **independentes** — os
  /// cartões aparecem todos juntos e a pessoa confirma ou descarta cada um,
  /// em qualquer ordem. Uma chamada inválida não derruba as outras.
  ///
  /// Quem chama este método já tentou [handle] (roteador primeiro) e já
  /// verificou chave e consentimento — o pipeline não sabe de rede.
  Future<PlanResult> handleWith(PlanningToolCaller caller, String userInput) async {
    final plan = await caller.plan(userInput, registry.specs);
    return PlanResult(plan.messages, await runPlan(plan));
  }

  /// Só a parte de validar, confirmar e executar de um plano já obtido —
  /// para quem quer mostrar as mensagens da IA antes dos cartões.
  Future<List<PipelineResult>> runPlan(ToolCallPlan plan) => Future.wait(plan.calls.map(_run));

  Future<PipelineResult> _run(ToolCallDecision decision) async {
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

    try {
      final result = await registry.execute(decision.toolName, decision.params);
      return PipelineResult.executed(decision.toolName, result);
    } on ToolValidationException catch (e) {
      // A pessoa editou o cartão para um valor inválido: o registro valida
      // de novo antes de executar.
      return PipelineResult.rejected(decision.toolName, e.errors);
    }
  }
}

/// Resultado de [BrainPipeline.handleWith]: as mensagens da IA e o
/// resultado de cada chamada, na ordem em que vieram.
class PlanResult {
  final List<String> messages;
  final List<PipelineResult> results;
  const PlanResult(this.messages, this.results);
}
