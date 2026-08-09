/// Contrato único de ferramentas entre o cérebro e os módulos
/// (`docs/ARQUITETURA.md`).
///
/// Fase 5: `ToolSpec` (contrato), `ToolRegistry` (registro + execução
/// validada) e validação por JSON Schema. Não sabe nada sobre LLM,
/// roteador ou qualquer módulo específico — isso é responsabilidade de
/// `packages/brain` e de cada módulo dono de ferramenta.
library;

export 'src/tool_registry.dart';
export 'src/tool_result.dart';
export 'src/tool_spec.dart';
export 'src/validation.dart';
