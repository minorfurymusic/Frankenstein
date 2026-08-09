/// Camada do cérebro — roteador determinístico, contrato de tool-calling,
/// validação, confirmação humana (`docs/ARQUITETURA.md`,
/// `.claude/rules/brain.md`, ADR-2).
///
/// Fase 5: pipeline completo com **1 ferramenta** provada de ponta a
/// ponta (ver `packages/brain/test`). A chamada real ao MLC LLM
/// on-device **não está implementada** — [ToolCaller] é a interface que
/// vai receber essa implementação depois, sem reescrever o pipeline;
/// nesta fase, [DeterministicRouter] é a única implementação concreta.
library;

export 'src/brain_pipeline.dart';
export 'src/confirmation.dart';
export 'src/deterministic_router.dart';
export 'src/pipeline_result.dart';
export 'src/tool_caller.dart';
