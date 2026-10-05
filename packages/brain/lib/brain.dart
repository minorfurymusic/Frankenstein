/// Camada do cérebro — roteador determinístico, contrato de tool-calling,
/// validação, confirmação humana (`docs/ARQUITETURA.md`,
/// `.claude/rules/brain.md`, ADR-2).
///
/// Roteador determinístico primeiro ([ToolCaller]/[DeterministicRouter]);
/// o que ele não resolve pode ir à IA em nuvem com a chave do usuário
/// ([PlanningToolCaller], ADR-11), que propõe várias chamadas de uma vez.
library;

export 'src/brain_pipeline.dart';
export 'src/confirmation.dart';
export 'src/deterministic_router.dart';
export 'src/pipeline_result.dart';
export 'src/tool_caller.dart';
