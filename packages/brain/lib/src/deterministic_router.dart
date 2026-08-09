import 'package:frankstein_tool_registry/tool_registry.dart';

import 'tool_caller.dart';

/// Extrai os parâmetros da ferramenta a partir do casamento de um
/// [RouterRule.pattern] contra o texto do usuário.
typedef ParamExtractor = Map<String, dynamic> Function(RegExpMatch match);

/// Uma regra do roteador: se [pattern] casa com o texto, chama
/// [toolName] com os parâmetros que [extractParams] tirar do match.
class RouterRule {
  final String toolName;
  final RegExp pattern;
  final ParamExtractor extractParams;

  RouterRule({
    required this.toolName,
    required this.pattern,
    required this.extractParams,
  });
}

/// O roteador determinístico — passo 1 do pipeline
/// (`.claude/rules/brain.md`): "Comando frequente NÃO chama o modelo."
/// É o caminho **principal**, não um atalho — o único que existe para o
/// Perfil C (`docs/OFFLINE-IA.md`: "sem modelo, roteador + templates, e
/// precisa funcionar bem").
///
/// Genérico de propósito: não sabe nada sobre `log_meal` nem sobre
/// nenhuma ferramenta específica — as regras são dados, registrados por
/// quem monta o pipeline (ver `packages/brain/test` para o exemplo com
/// `log_meal`).
class DeterministicRouter implements ToolCaller {
  final List<RouterRule> rules;

  DeterministicRouter(this.rules);

  @override
  ToolCallDecision? decide(String userInput, List<ToolSpec> availableTools) {
    for (final rule in rules) {
      final match = rule.pattern.firstMatch(userInput);
      if (match != null) {
        return ToolCallDecision(rule.toolName, rule.extractParams(match));
      }
    }
    return null;
  }
}
