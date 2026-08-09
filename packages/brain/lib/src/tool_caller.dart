import 'package:frankstein_tool_registry/tool_registry.dart';

/// O que um [ToolCaller] decidiu: qual ferramenta chamar, com quais
/// parâmetros — ainda não validados, isso é passo seguinte do pipeline.
class ToolCallDecision {
  final String toolName;
  final Map<String, dynamic> params;
  ToolCallDecision(this.toolName, this.params);
}

/// Decide qual ferramenta chamar (e com quais parâmetros) a partir de
/// texto livre do usuário — ou `null` se não conseguir decidir.
///
/// `.claude/rules/brain.md` define dois passos concretos do pipeline que
/// implementam isto, nesta ordem: (1) roteador determinístico — ver
/// [DeterministicRouter] — e (2) LLM com tool-calling, só para o que o
/// roteador não resolveu. **O passo 2 (MLC LLM real, on-device) não está
/// implementado nesta fase** — exige validação em Android físico/emulador,
/// que este ambiente de desenvolvimento não tem (mesmo limite já
/// registrado no Ciclo 27 do `docs/HISTORICO.md`). Esta interface existe
/// para que a implementação futura seja uma classe nova implementando
/// [ToolCaller], não uma reescrita do pipeline.
abstract class ToolCaller {
  ToolCallDecision? decide(String userInput, List<ToolSpec> availableTools);
}
