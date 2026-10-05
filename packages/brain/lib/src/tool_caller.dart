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
/// `.claude/rules/brain.md` define dois passos, nesta ordem: (1) roteador
/// determinístico — ver [DeterministicRouter], síncrono, sem rede — e
/// (2) a IA, só para o que o roteador não resolveu — ver
/// [PlanningToolCaller].
abstract class ToolCaller {
  ToolCallDecision? decide(String userInput, List<ToolSpec> availableTools);
}

/// O que um [PlanningToolCaller] entendeu de uma mensagem: várias chamadas
/// (uma por registro — "bebi 2 L de água e comi 3 ovos" vira duas) e
/// mensagens curtas para mostrar à pessoa (pergunta, aviso), que nunca
/// gravam nada.
class ToolCallPlan {
  final List<ToolCallDecision> calls;
  final List<String> messages;
  const ToolCallPlan({this.calls = const [], this.messages = const []});
}

/// Passo 2 do pipeline (`.claude/rules/brain.md`): a IA, só para o que o
/// roteador determinístico não resolveu. Assíncrono porque chama a rede
/// (com a chave do usuário — ADR-11); quem chama decide antes se pode
/// enviar (chave configurada, consentimento dado).
abstract class PlanningToolCaller {
  Future<ToolCallPlan> plan(String userInput, List<ToolSpec> availableTools);
}
