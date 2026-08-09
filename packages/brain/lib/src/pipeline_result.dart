import 'package:frankstein_tool_registry/tool_registry.dart';

enum PipelineOutcome {
  /// Nenhum [ToolCaller] conseguiu decidir uma ferramenta pro texto do
  /// usuário — nem o roteador, nem (quando existir) o LLM.
  unresolved,

  /// Uma ferramenta foi decidida, mas os parâmetros não bateram no
  /// JSON Schema dela — rejeitado antes de pedir confirmação ou
  /// executar.
  rejected,

  /// A ferramenta exigia confirmação humana (`ToolSpec.confirm`) e o
  /// usuário não confirmou.
  abortedByUser,

  /// Ferramenta executada de verdade.
  executed,
}

/// O resultado de rodar [BrainPipeline.handle] uma vez.
class PipelineResult {
  final PipelineOutcome outcome;
  final String? toolName;
  final List<String>? validationErrors;
  final ToolResult? toolResult;

  PipelineResult._(
    this.outcome, {
    this.toolName,
    this.validationErrors,
    this.toolResult,
  });

  factory PipelineResult.unresolved() =>
      PipelineResult._(PipelineOutcome.unresolved);

  factory PipelineResult.rejected(String toolName, List<String> errors) =>
      PipelineResult._(
        PipelineOutcome.rejected,
        toolName: toolName,
        validationErrors: errors,
      );

  factory PipelineResult.abortedByUser(String toolName) =>
      PipelineResult._(PipelineOutcome.abortedByUser, toolName: toolName);

  factory PipelineResult.executed(String toolName, ToolResult result) =>
      PipelineResult._(
        PipelineOutcome.executed,
        toolName: toolName,
        toolResult: result,
      );
}
